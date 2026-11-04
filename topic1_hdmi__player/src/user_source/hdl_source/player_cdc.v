// Assert asynchronously; release only on a local clock edge.
module player_reset_sync(input clk, async_rst, output rst);
(* syn_preserve = 1, syn_keep = 1 *) reg [2:0] pipe = 3'b111;
always @(posedge clk or posedge async_rst)
    if (async_rst) pipe<=3'b111;
    else pipe<={pipe[1:0],1'b0};
assign rst=pipe[2];
endmodule

// Source holds the bundled bank/image bus from request until ACK. Request has
// one extra synchronization stage, so the data is settled before observation.
module player_frame_commit #(
    parameter FADE_ENABLE = 1,
    parameter integer FRAMES_PER_STEP = 1
)(
    input clk, rst, frame_start, request_toggle,
    input [1:0] requested_bank, requested_image,
    output reg ack_toggle,
    output reg [1:0] active_bank, active_image,
    output reg valid,
    output reg [5:0] fade_gain,
    output busy
);
localparam IDLE=0, FADE_OUT=1, BLACK_SWAP=2, FADE_IN=3;
localparam integer STEP_FRAMES = FRAMES_PER_STEP < 1 ? 1 : FRAMES_PER_STEP;
localparam integer COUNT_BITS = STEP_FRAMES < 2 ? 1 : $clog2(STEP_FRAMES);
reg [COUNT_BITS-1:0] step_count;
reg [1:0] state, pending_bank, pending_image;
reg pending_toggle;
reg [2:0] req_sync;
assign busy = (state != IDLE) || (req_sync[2] != ack_toggle);
reg [1:0] bank_d0, bank_d1, image_d0, image_d1;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        req_sync<=0; bank_d0<=0; bank_d1<=0; image_d0<=0; image_d1<=0;
        ack_toggle<=0; active_bank<=0; active_image<=0; valid<=0;
        fade_gain<=0; state<=IDLE; step_count<=0;
        pending_bank<=0; pending_image<=0; pending_toggle<=0;
    end else begin
        req_sync<={req_sync[1:0],request_toggle};
        bank_d0<=requested_bank; bank_d1<=bank_d0;
        image_d0<=requested_image; image_d1<=image_d0;
        if (frame_start) begin
            case (state)
            IDLE: if (req_sync[2]!=ack_toggle) begin
                pending_bank<=bank_d1; pending_image<=image_d1;
                pending_toggle<=req_sync[2]; step_count<=0;
                if (!FADE_ENABLE) begin
                    active_bank<=bank_d1; active_image<=image_d1;
                    valid<=1; fade_gain<=32; ack_toggle<=req_sync[2];
                end else if (!valid) begin
                    active_bank<=bank_d1; active_image<=image_d1;
                    valid<=1; fade_gain<=0; state<=FADE_IN;
                end else begin
                    // Keep the old image until it is completely black.
                    state<=FADE_OUT;
                end
            end
            FADE_OUT, FADE_IN: begin
                if (step_count == STEP_FRAMES-1) begin
                    step_count<=0;
                    if (state==FADE_OUT) begin
                        fade_gain<=fade_gain-1'b1;
                        if (fade_gain==1) state<=BLACK_SWAP;
                    end else begin
                        fade_gain<=fade_gain+1'b1;
                        if (fade_gain==31) begin
                            state<=IDLE; ack_toggle<=pending_toggle;
                        end
                    end
                end else step_count<=step_count+1'b1;
            end
            BLACK_SWAP: begin
                // One full black frame on either side of the bank switch.
                active_bank<=pending_bank; active_image<=pending_image;
                state<=FADE_IN; step_count<=0;
            end
            default: state<=IDLE;
            endcase
        end
    end
end
endmodule
