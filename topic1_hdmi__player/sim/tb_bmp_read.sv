`timescale 1ns/1ps
module tb_bmp_read;
reg clk=0; always #5 clk=~clk;
reg rst=1, scan_start=0, load_start=0, abort_load=0;
reg [31:0] load_sector=3;
wire ready,scan_done,found_valid,done,err,req,read,valid,endsec,we;
wire [31:0] found_sector,addr;
wire [2:0] found_total;
wire [7:0] data;
wire [23:0] pixel;
reg ack=0;
reg [7:0] byte_data=0;
reg byte_valid=0,sector_end=0;
integer mode=0, pos, i, pixels=0, found=0, cycles=0;
reg done_seen=0,error_seen=0;
assign data=byte_data; assign valid=byte_valid; assign endsec=sector_end;
bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),
 .scan_start_sector(32'd0),.scan_max_sector(32'd4000),.scan_target_count(3'd2),
 .scan_done(scan_done),.scan_found_valid(found_valid),.scan_found_sector(found_sector),.scan_found_total(found_total),
 .load_start(load_start),.load_abort(abort_load),.load_sector(load_sector),.load_done(done),.load_error(err),
 .sd_init_done(!rst),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(req),.write_req_ack(ack),.sd_sec_read(read),.sd_sec_read_addr(addr),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(endsec),
 .bmp_data_wr_en(we),.bmp_data(pixel));
function automatic [7:0] image_byte(input integer offset, input integer bad);
 integer length,p;
 begin
 length=921754; // 100 bytes after pixels MUST NOT become extra pixels.
 if(bad==5) length=100;
 image_byte=0;
 case(offset)
 0:image_byte="B"; 1:image_byte="M";
 2:image_byte=length; 3:image_byte=length>>8; 4:image_byte=length>>16;
 10:image_byte=54; 14:image_byte=(bad==4)?12:40;
 18:image_byte=8'h80;19:image_byte=2;20:image_byte=(bad==1)?1:0;
 22:image_byte=8'he0;23:image_byte=1;25:image_byte=(bad==2)?8'hff:0;
 26:image_byte=(bad==3)?2:1;28:image_byte=24;
 default: if(offset>=54 && offset<921654) begin
     p=(offset-54)/3;
     case((offset-54)%3)
      0:image_byte=p; 1:image_byte=p>>8; 2:image_byte=(p & 255)^8'ha5;
     endcase
 end
 endcase
 end
endfunction
// Behavioral sector interface, independently driven on the falling edge.
initial forever begin
 @(negedge clk);
 if(read && !rst) begin
   pos=(addr>=1805 ? (addr-1805) : (addr-3))*512;
   for(i=0;i<((mode==6 || (mode==7 && dut.state==4))?100:512);i=i+1) begin
     byte_data=(addr<3 || addr==1804)?0:image_byte(pos+i,mode);
     byte_valid=1; @(negedge clk);
   end
   byte_valid=0; sector_end=1; @(negedge clk);
   sector_end=0; @(negedge clk);
 end
end
always @(posedge clk) begin
 ack<=req;
 if(done) done_seen<=1;
 if(err) error_seen<=1;
 if(found_valid) begin
   if(found_sector != (found==0 ? 3:1805)) $fatal(1,"wrong discovered LBA %0d",found_sector);
   found<=found+1;
 end
 if(we) begin
   if(pixel !== {8'((pixels&255)^8'ha5),8'(pixels>>8),8'(pixels)})
     $fatal(1,"pixel %0d mismatch %h",pixels,pixel);
   pixels<=pixels+1;
 end
 cycles<=cycles+1;
 if(cycles>2500000) $fatal(1,"watchdog");
end
task start_load;
 begin
 @(negedge clk); done_seen=0;error_seen=0;pixels=0; load_start=1;
 @(negedge clk);load_start=0;
 wait(done_seen || error_seen); repeat(4) @(negedge clk);
 end
endtask
initial begin
 repeat(4) @(negedge clk);rst=0;scan_start=1;
 @(negedge clk);scan_start=0;
 wait(scan_done);repeat(3) @(negedge clk);
 if(found!=2 || found_total!=2) $fatal(1,"scan count");
 start_load();
 if(!done_seen || error_seen || pixels!=307200) $fatal(1,"full frame count %0d",pixels);
 for(mode=1;mode<=7;mode=mode+1) begin
   start_load();
   if(done_seen || !error_seen || pixels!=(mode==7?15:0)) $fatal(1,"malformed image accepted mode=%0d",mode);
 end
 $display("PASS tb_bmp_read: discovery, 307200 RGB pixels, trailing bytes, malformed headers, short header/data sectors");
 $finish;
end
endmodule
