// Status inside artwork's empty scope panel. Chinese rolling explanation below.
module science_osd(input clk,rst,hs,vs,de,input [23:0] rgb,
 input [1:0] page,choice,volume,period_sel,input menu_open,auto_play,subtitle_enable,
 input [2:0] field,contrast,input [3:0] brightness,input loading,
 output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out);
reg de_d,vs_d;reg [9:0] x,y;
wire [9:0] xc=de ? (de_d ? x+10'd1:10'd0):10'd0;
wire frame_edge=vs_d&&!vs;
reg [10:0] scroll;
reg [1:0] last_page;
wire [11:0] sx={2'b0,xc}+{1'b0,scroll};
wire [11:0] tx=sx-12'd640;
wire [5:0] zh_cell=tx[9:4];
wire [15:0] zh_pixels;
science_subtitle_rom subtitles(clk,page,zh_cell,y[3:0],zh_pixels);
// y=448 is aligned to a 16-row font; text occupies 448..463.
wire sub_area=subtitle_enable && y>=444 && y<468;
wire sub_ink_area=subtitle_enable && y>=448 && y<464 && sx>=640 && tx<1024;
wire header=y>=320 && y<334;
wire hint=y>=418 && y<432;
wire menu1=menu_open && y>=256 && y<270;
wire menu2=menu_open && y>=280 && y<294;
wire ascii_area=xc>=32 && xc<608 && (header||hint||menu1||menu2);
wire [9:0] dx=xc-10'd32;
wire [9:0] dy=header ? y-10'd320:hint ? y-10'd418:menu1 ? y-10'd256:y-10'd280;
wire [5:0] cell_id=dx[9:4];
reg [287:0] line;
reg [7:0] ch;
reg [7:0] bri,con;
reg selected;
always @* begin
 bri=brightness>=4 ? (brightness-4)*16:(4-brightness)*16;
 con=50+contrast*25;
 line="                                    ";
 if(header)case(page)
  0:case(choice)
   0:line="SINE       440HZ   OUT         VOL 2";
   1:line="TRIANGLE   440HZ   OUT         VOL 2";
   2:line="SQUARE     440HZ   OUT         VOL 2";
   3:line="STOP       440HZ   OUT         VOL 2";
  endcase
  1:case(choice)
   0:line="FREQ 220HZ  T 4.55MS  OUT      VOL 2";
   1:line="FREQ 440HZ  T 2.27MS  OUT      VOL 2";
   default:line="FREQ 880HZ  T 1.14MS  OUT      VOL 2";
  endcase
  2:case(choice)
   0:line="440HZ AMP  25%     OUT         VOL 2";
   1:line="440HZ AMP  50%     OUT         VOL 2";
   2:line="440HZ AMP 100%     OUT         VOL 2";
   3:line="440HZ AMP   0%     OUT         VOL 2";
  endcase
  3:case(choice)
   0:line="MUSIC     CYAN BGM  WHITE OUT  VOL 2";
   1:line="CUE       CYAN BGM  WHITE OUT  VOL 2";
   2:line="MIX       CYAN BGM  WHITE OUT  VOL 2";
   3:line="STOP      CYAN BGM  WHITE OUT  VOL 2";
  endcase
 endcase
 else if(hint)line=loading ? "LOADING... PLEASE WAIT              ":"K3 PREV   K2 NEXT   K4 CHANGE / MENU";
 else if(menu1)line="VOL 2    BRI +00    CON 100         ";
 else if(menu2)line="SUB 1    AUTO 0     TIME 05S        ";
 ch=line[(35-cell_id)*8+:8];
 selected=0;
 if(header && cell_id==35)ch="0"+volume;
 if(menu1)begin
  case(cell_id)
   4:ch="0"+volume;
   13:ch=brightness<4 ? "-":"+";
   14:ch="0"+bri/10;15:ch="0"+bri%10;
   24:ch="0"+con/100;25:ch="0"+(con/10)%10;26:ch="0"+con%10;
  endcase
  selected=(field==0&&cell_id<=4)||(field==1&&cell_id>=9&&cell_id<=15)||(field==2&&cell_id>=19&&cell_id<=26);
 end
 if(menu2)begin
  case(cell_id)
   4:ch=subtitle_enable ? "1":"0";
   14:ch=auto_play ? "1":"0";
   25:ch=period_sel==2 ? "1":"0";
   26:ch=period_sel==0 ? "2":period_sel==1 ? "5":"0";
  endcase
  selected=(field==3&&cell_id<=4)||(field==4&&cell_id>=9&&cell_id<=14)||(field==5&&cell_id>=19&&cell_id<=26);
 end
end
// BEGIN ASCII GLYPHS
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
        "H":glyph={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
"W":glyph={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b11011,5'b10001};
"Z":glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111};
"Q":glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10101,5'b10010,5'b01101};
"%":glyph={5'b11001,5'b11010,5'b00100,5'b01000,5'b10110,5'b00110,5'b00000};
".":glyph={5'b00000,5'b00000,5'b00000,5'b00000,5'b00000,5'b00100,5'b00100};
"/":glyph={5'b00001,5'b00010,5'b00010,5'b00100,5'b01000,5'b01000,5'b10000};
default:glyph=0;
        endcase
    end
endfunction
// END ASCII GLYPHS
wire [34:0] bitmap=glyph(ch);
wire ascii_ink=ascii_area && dx[3:1]<5 && dy[3:1]<7 && bitmap[34-dy[3:1]*5-dx[3:1]];
reg h1,v1,d1,sub1,zh1,ascii1,ink1,select1;
reg [3:0] zcol1;reg [23:0] rgb1;
wire [23:0] dim={1'b0,rgb1[23:17],1'b0,rgb1[15:9],1'b0,rgb1[7:1]};
always @(posedge clk or posedge rst)begin
 if(rst)begin
  de_d<=0;vs_d<=0;x<=0;y<=0;scroll<=640;last_page<=0;
  h1<=0;v1<=0;d1<=0;sub1<=0;zh1<=0;ascii1<=0;ink1<=0;select1<=0;zcol1<=0;rgb1<=0;
  hs_out<=0;vs_out<=0;de_out<=0;rgb_out<=0;
 end else begin
  de_d<=de;vs_d<=vs;x<=xc;
  if(frame_edge)begin
   y<=0;last_page<=page;scroll<=page!=last_page ? 640:scroll>=1662 ? 0:scroll+2;
  end else if(de_d&&!de)y<=y+1'b1;
  h1<=hs;v1<=vs;d1<=de;rgb1<=rgb;sub1<=sub_area;zh1<=sub_ink_area;zcol1<=tx[3:0];
  ascii1<=ascii_area;ink1<=ascii_ink;select1<=selected;
  hs_out<=h1;vs_out<=v1;de_out<=d1;
  rgb_out<=!d1 ? 24'd0 : ascii1 ? (ink1 ? (select1 ? 24'hffcc55:24'he8f4ff):24'h071522):
   sub1 ? (zh1&&zh_pixels[15-zcol1] ? 24'hffffff:dim):rgb1;
 end
end
endmodule
