// Two-row settings panel and frame-stepped scrolling subtitle.
// Coordinates follow the input DE; RGB and all sync signals delay together.
module player_settings_osd #(parameter integer PIXEL_HZ=25000000)(
    input clk,rst,hs,vs,de,input [23:0] rgb,
    input menu_open,input [2:0] field,input [1:0] period_sel,volume,input two_note,
    output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out,
    input [3:0] brightness,input [2:0] contrast,input subtitle_enable,input [1:0] image_id
);
reg de_d,vs_d;
reg [9:0] x,y;
reg [10:0] scroll;
reg [24:0] seconds_div;
reg [3:0] sec_ones,sec_tens,min_ones,min_tens;
reg [3:0] show_so,show_st,show_mo,show_mt;
reg [1:0] show_image;
wire frame_edge=vs_d && !vs;
wire [9:0] xc=de ? (de_d ? x+10'd1 : 10'd0) : 10'd0;
wire second_line=y>=60 && y<78;
wire [9:0] dx=xc-10'd8,dy=second_line ? y-10'd60 : y-10'd36;
wire [4:0] cell_index=dx[8:4];
wire in_panel=menu_open && xc>=8 && xc<360 && ((y>=36 && y<54) || second_line);
// 48 characters * 16px, preceded by 640px blank; 2px/frame, exact wrap.
wire [11:0] scroll_x={2'b0,xc}+{1'b0,scroll};
wire [11:0] text_x=scroll_x-12'd640;
wire [5:0] subtitle_cell=text_x[9:4];
wire [9:0] subtitle_y=y-10'd448;
wire in_subtitle=subtitle_enable && y>=444 && y<468;
reg [7:0] character;
reg [7:0] bri_mag,con_percent;
always @* begin
    bri_mag=brightness>=4 ? (brightness-4)*16 : (4-brightness)*16;
    con_percent=50+contrast*25;
    character=" ";
    if(in_subtitle) begin
        if(scroll_x>=640 && text_x<768) case(subtitle_cell)
            0:character="F";
            1:character="I";
            2:character="R";
            3:character="E";
            4:character=" ";
            5:character="S";
            6:character="A";
            7:character="F";
            8:character="E";
            9:character="T";
            10:character="Y";
            11:character=" ";
            12:character=" ";
            13:character="K";
            14:character="E";
            15:character="E";
            16:character="P";
            17:character=" ";
            18:character="E";
            19:character="X";
            20:character="I";
            21:character="T";
            22:character="S";
            23:character=" ";
            24:character="C";
            25:character="L";
            26:character="E";
            27:character="A";
            28:character="R";
            29:character=" ";
            30:character=" ";
            31:character=" ";
            32:character="P";
            33:character="I";
            34:character="C";
            35:character=" ";
            36:character="1"+show_image;
            38:character="T";39:character="I";40:character="M";41:character="E";
            43:character="0"+show_mt;44:character="0"+show_mo;45:character=":";
            46:character="0"+show_st;47:character="0"+show_so;
            default:character=" ";
        endcase
    end else if(second_line) begin
        case(cell_index)
            0:character="B";1:character="R";2:character="I";
            4:character=brightness<4 ? "-" : "+";
            5:character="0"+bri_mag/10;6:character="0"+bri_mag%10;
            9:character="C";10:character="O";11:character="N";
            13:character="0"+con_percent/100;
            14:character="0"+(con_percent/10)%10;15:character="0"+con_percent%10;
            18:character="S";19:character="U";20:character="B";
            21:character=subtitle_enable ? "1" : "0";
            default:character=" ";
        endcase
    end else begin
        case(cell_index)
            0:character="T";1:character="I";2:character="M";3:character="E";
            5:character=period_sel==2 ? "1" : "0";
            6:character=period_sel==0 ? "2" : period_sel==1 ? "5" : "0";
            7:character="s";
            9:character="V";10:character="O";11:character="L";
            13:character="0"+volume;
            15:character="S";16:character="N";17:character="D";
            19:character=two_note ? "2" : "1";
            default:character=" ";
        endcase
    end
end
function [34:0] glyph;
    input [7:0] c;
    begin
        case(c)
        "K":glyph={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
        "X":glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
        "T":glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
        "I":glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
        "M":glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
        "E":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
        "V":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
        "O":glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
        "L":glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
        "S","s":glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
        "N":glyph={5'b10001,5'b11001,5'b11001,5'b10101,5'b10011,5'b10011,5'b10001};
        "D":glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
        "0":glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
        "1":glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
        "2":glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
        "3":glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
        "5":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
        "A":glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
        "B":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
        "C":glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
        "F":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
        "G":glyph={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
        "P":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
        "R":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
        "U":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
        "Y":glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
        "4":glyph={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
        "6":glyph={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
        "7":glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
        "8":glyph={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
        "9":glyph={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
        "+":glyph={5'b00000,5'b00100,5'b00100,5'b11111,5'b00100,5'b00100,5'b00000};
        "-":glyph={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
        ":":glyph={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
        default:glyph=0;
        endcase
    end
endfunction
wire [2:0] col=in_subtitle ? text_x[3:1] : dx[3:1];
wire [2:0] row=in_subtitle ? subtitle_y[3:1] : dy[3:1];
wire [34:0] bitmap=glyph(character);
wire ink=col<5 && row<7 && (in_subtitle ? (y>=448 && y<462) : dy<14) && bitmap[34-row*5-col];
wire selected=second_line ? ((field==3 && cell_index<=6) ||
               (field==4 && cell_index>=9 && cell_index<=15) || (field==5 && cell_index>=18)) :
               ((field==0 && cell_index<=7) || (field==1 && cell_index>=9 && cell_index<=13) ||
               (field==2 && cell_index>=15 && cell_index<=19));
// Half-bright picture under the subtitle strip, white text on top.
wire [23:0] dim_rgb={1'b0,rgb[23:17],1'b0,rgb[15:9],1'b0,rgb[7:1]};
always @(posedge clk or posedge rst) begin
    if(rst) begin
        de_d<=0;vs_d<=0;x<=0;y<=0;scroll<=640;seconds_div<=0;
        sec_ones<=0;sec_tens<=0;min_ones<=0;min_tens<=0;
        show_so<=0;show_st<=0;show_mo<=0;show_mt<=0;show_image<=0;
        hs_out<=0;vs_out<=0;de_out<=0;rgb_out<=0;
    end else begin
        de_d<=de;vs_d<=vs;hs_out<=hs;vs_out<=vs;de_out<=de;
        if(seconds_div==PIXEL_HZ-1) begin
            seconds_div<=0;
            if(sec_ones==9) begin
                sec_ones<=0;
                if(sec_tens==5) begin
                    sec_tens<=0;
                    if(min_ones==9) begin min_ones<=0;min_tens<=min_tens==9 ? 0 : min_tens+1'b1;end
                    else min_ones<=min_ones+1'b1;
                end else sec_tens<=sec_tens+1'b1;
            end else sec_ones<=sec_ones+1'b1;
        end else seconds_div<=seconds_div+1'b1;
        if(frame_edge) begin
            x<=0;y<=0;scroll<=scroll>=1406 ? 0 : scroll+2;
            show_so<=sec_ones;show_st<=sec_tens;show_mo<=min_ones;show_mt<=min_tens;
            show_image<=image_id;
        end else if(de) x<=xc;
        else if(de_d) begin x<=0;if(y<511)y<=y+1'b1;end
        rgb_out<=!de ? 24'd0 : in_panel ? (!ink ? 24'h101828 : selected ? 24'hffff00 : 24'he0e0e0) :
                 in_subtitle ? (ink ? 24'hffffff : dim_rgb) : rgb;
    end
end
endmodule

