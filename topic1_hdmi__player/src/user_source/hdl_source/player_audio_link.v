// Observe committed pictures, never speculative SD requests. With fade enabled
// this event occurs at the black-frame bank swap, before the new picture fades in.
module player_picture_event(
    input clk, rst, valid,
    input [1:0] bank, image_id,
    output reg event_toggle,
    output reg [1:0] event_image,
    input two_note,
    output reg event_two_note
);
reg seen_valid;
reg [1:0] seen_bank, seen_image;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        seen_valid<=0; seen_bank<=0; seen_image<=0;
        event_toggle<=0; event_image<=0; event_two_note<=0;
    end else begin
        seen_valid<=valid;
        if (valid && (!seen_valid || bank!=seen_bank || image_id!=seen_image)) begin
            event_toggle<=~event_toggle;
            event_image<=image_id;
            event_two_note<=two_note;
            seen_bank<=bank; seen_image<=image_id;
        end
    end
end
endmodule

// Internal transport compatible with the existing I2S_receiver: 64 BCLK bits
// per channel, 128 per stereo frame, BCLK=MCLK/2, Fs=MCLK/256 (~48 kHz).
// This is the inherited internal framing, not an external standard-I2S port.
// Source holds event_image AND I_two_note until the next picture event.
// Toggle has one more CDC stage than the bundled payload; consume at Fs edge.
module hdmi_audio_link_i2s #(
    parameter integer CUE_SAMPLES = 12000,
    parameter [23:0] AMP = 24'd500000
)(
    input I_mclk, I_rst, I_event_toggle,
    input [1:0] I_image_id,
    output reg O_i2s_BCLK, O_i2s_LRCK, O_i2s_DOUT,
    input [1:0] I_volume,
    input I_two_note
);
localparam integer DURATION = CUE_SAMPLES < 4 ? 4 : CUE_SAMPLES;
localparam integer RAMP = DURATION < 1024 ? DURATION/4 : 256;
localparam integer COUNT_BITS = $clog2(DURATION+1);
localparam [23:0] AMP_STEP = (AMP / RAMP) < 1 ? 1 : (AMP / RAMP);
(* syn_preserve = 1 *) reg [2:0] event_sync;
reg [1:0] image_d0, image_d1;
reg mode_d0,mode_d1;
reg event_seen;
reg [5:0] bit_count;
reg [63:0] shift_data;
reg [23:0] sample_word, envelope;
reg [31:0] phase_acc, phase_inc;
reg [COUNT_BITS-1:0] remaining;
reg second_pending;
reg [31:0] second_inc;
// Volume is already coherently transferred to I_mclk. Mode belongs to the
// source's picture-event payload, not the independently transferred settings.
// Each stereo pair uses one locked sample; volume takes effect next sample.
wire [23:0] scaled_envelope=I_volume==0 ? 24'd0 : I_volume==1 ? envelope>>2 :
                                  I_volume==2 ? envelope>>1 : envelope;
wire new_event = event_sync[2]!=event_seen;
wire [23:0] next_sample = new_event || remaining==0 ? 24'd0 :
                         (phase_acc[31] ? (~scaled_envelope + 24'd1) : scaled_envelope);
function [31:0] image_note;
    input [1:0] index;
    begin
        case(index)
            0: image_note=32'd23409862; // C4, ~262 Hz
            1: image_note=32'd29494578; // E4, ~330 Hz
            2: image_note=32'd35075155; // G4, ~392 Hz
            3: image_note=32'd46819716; // C5, ~523 Hz
        endcase
    end
endfunction
function [31:0] image_second_note;
    input [1:0] index;
    begin
        case(index)
            0: image_second_note=32'd29494578; // C4 -> E4
            1: image_second_note=32'd35075155; // E4 -> G4
            2: image_second_note=32'd46819716; // G4 -> C5
            3: image_second_note=32'd58989156; // C5 -> E5
        endcase
    end
endfunction
always @(posedge I_mclk or posedge I_rst) begin
    if (I_rst) begin
        event_sync<=0; image_d0<=0; image_d1<=0; event_seen<=0;mode_d0<=0;mode_d1<=0;
        O_i2s_BCLK<=0; O_i2s_LRCK<=0; O_i2s_DOUT<=0;
        bit_count<=0; shift_data<=0; sample_word<=0;
        envelope<=0; phase_acc<=0; phase_inc<=0; remaining<=0;
        second_pending<=0;second_inc<=0;
    end else begin
        event_sync<={event_sync[1:0],I_event_toggle};
        image_d0<=I_image_id; image_d1<=image_d0;
        mode_d0<=I_two_note;mode_d1<=mode_d0;
        O_i2s_BCLK<=~O_i2s_BCLK;
        if (O_i2s_BCLK) begin
            O_i2s_DOUT<=shift_data[63];
            shift_data<={shift_data[62:0],1'b0};
            if (bit_count==63) begin
                bit_count<=0;
                O_i2s_LRCK<=~O_i2s_LRCK;
                if (!O_i2s_LRCK) begin
                    shift_data<={sample_word,40'd0};
                end else begin
                    sample_word<=next_sample;
                    shift_data<={next_sample,40'd0};
                    if (new_event) begin
                        event_seen<=event_sync[2];
                        phase_inc<=image_note(image_d1); phase_acc<=0;
                        remaining<=DURATION-1; envelope<=AMP_STEP;
                        second_pending<=mode_d1;second_inc<=image_second_note(image_d1);
                    end else if (remaining!=0) begin
                        remaining<=remaining-1'b1;
                        phase_acc<=phase_acc+phase_inc;
                        if (remaining<=RAMP)
                            envelope<=envelope>AMP_STEP ? envelope-AMP_STEP : 24'd0;
                        else if (envelope<AMP)
                            envelope<=envelope>AMP-AMP_STEP ? AMP : envelope+AMP_STEP;
                    end else if(second_pending) begin
                        second_pending<=0;phase_inc<=second_inc;phase_acc<=0;
                        remaining<=DURATION-1;envelope<=AMP_STEP;
                    end else envelope<=0;
                end
            end else bit_count<=bit_count+1'b1;
        end
    end
end
endmodule
