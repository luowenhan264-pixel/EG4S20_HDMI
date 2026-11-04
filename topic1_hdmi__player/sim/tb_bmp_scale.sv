`timescale 1ns/1ps
module tb_bmp_scale;
reg clk=0; always #5 clk=~clk;
reg rst=1, scan_start=0, load_start=0, abort_load=0, ack=0;
reg [15:0] dw=640, dh=480;
reg [7:0] data=0;
reg valid=0, endsec=0;
wire ready, scan_done, found_valid, done, err, req, read, we;
wire [31:0] addr, found_sector;
wire [2:0] found_total;
wire [23:0] pixel;
integer sw=640, sh=480, off=54, top_down=0, bad=0, short_data=0;
integer pixels=0, cycles=0, requests=0, phase=0, index=0, latched_addr=0;
integer start_cycle=0, stalls=0, found_count=0;
reg done_seen=0, error_seen=0, previous_ready=0;
wire pixel_ready=(cycles%1700)<1050;
bmp_scale_read dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),.scan_start_sector(32'd0),
 .scan_max_sector(32'd6),.scan_target_count(3'd1),.scan_done(scan_done),
 .scan_found_valid(found_valid),.scan_found_sector(found_sector),.scan_found_total(found_total),
 .load_start(load_start),.load_abort(abort_load),.load_sector(32'd3),.load_done(done),.load_error(err),
 .sd_init_done(!rst),.state_code(),.bmp_width(dw),.bmp_height(dh),
 .write_req(req),.write_req_ack(ack),.sd_sec_read(read),.sd_sec_read_addr(addr),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(endsec),
 .bmp_data_wr_en(we),.bmp_data(pixel),.pixel_ready(pixel_ready));

function automatic [23:0] colour(input integer x, y);
 colour={8'(x*7+y*3),8'(y*11+(x>>3)),8'(x^(y*13))};
endfunction
function automatic [7:0] byte_at(input integer p);
 integer stride, length, hh, q, row, x, c, dim_w, bits, dib, offset_value;
 reg [23:0] rgb;
 begin
 stride=(sw*3+3)&~3; length=off+stride*sh+100; hh=top_down ? -sh:sh;
 dim_w=sw; bits=24; dib=40; offset_value=off;
 case(bad)
 1:dim_w=0; 2:dim_w=2049; 3:hh=0; 4:hh=2049; 5:bits=32;
 6:dib=12; 7:length=off+stride*sh-1; 8:offset_value=4097;
 9:hh=-2049; 10:dim_w=-1;
 endcase
 byte_at=0;
 case(p)
 0:byte_at="B"; 1:byte_at="M";
 2,3,4,5:byte_at=length>>((p-2)*8);
 10,11,12,13:byte_at=offset_value>>((p-10)*8);
 14:byte_at=dib;
 18,19,20,21:byte_at=dim_w>>((p-18)*8);
 22,23,24,25:byte_at=hh>>((p-22)*8);
 26:byte_at=(bad==11)?2:1; 28:byte_at=bits; 30:byte_at=(bad==12)?1:0;
 default: if(p>=off && p<off+stride*sh) begin
    q=p-off; row=q/stride; x=(q%stride)/3; c=(q%stride)%3;
    rgb=colour(x,top_down ? row:sh-1-row);
    byte_at=(q%stride>=sw*3) ? 8'hee : (rgb>>(c*8));
 end else if(p>=off+stride*sh) byte_at=8'hdd;
 endcase
 end
endfunction

// CMD17 abstraction with mandatory idle turnaround, arbitrary file LBA.
always @(negedge clk) begin
 valid=0; endsec=0;
 if(rst || abort_load) phase=0;
 else case(phase)
 0:if(read) begin latched_addr=addr;index=0;phase=1; requests=requests+1;end
 1:begin
     data=latched_addr<3 ? 0 : byte_at((latched_addr-3)*512+index);
     valid=1;index=index+1;
     if(index==((short_data && dut.state==4)?100:512)) phase=2;
   end
 2:begin endsec=1;phase=3;end
 3:phase=0;
 endcase
end
always @(posedge clk) begin
 ack<=req; previous_ready<=pixel_ready;
 cycles<=cycles+1;
 if(cycles-start_cycle>25000000) $fatal(1,"scaling watchdog state=%d pixels=%d",dut.state,pixels);
 if(done) done_seen<=1;
 if(err) error_seen<=1;
 if(found_valid) begin
   if(found_sector!=3) $fatal(1,"scan LBA"); found_count<=found_count+1;
 end
 if(dut.state==8 && !pixel_ready) stalls<=stalls+1;
 if(we) begin
   if(!previous_ready) $fatal(1,"ignored backpressure");
   if(pixels>=dw*dh) $fatal(1,"too many pixels");
   if(pixel!==colour(((pixels%dw)*sw)/dw,((pixels/dw)*sh)/dh))
     $fatal(1,"%dx%d -> %dx%d pixel %d got %h expected %h",sw,sh,dw,dh,pixels,pixel,colour(((pixels%dw)*sw)/dw,((pixels/dw)*sh)/dh));
   pixels<=pixels+1;
 end
end
task start;
 begin
 @(negedge clk);pixels=0;done_seen=0;error_seen=0;start_cycle=cycles;load_start=1;
 @(negedge clk);load_start=0;
 end
endtask
task run_image(input integer w,h,td,offset_arg);
 integer r0;
 begin
 sw=w;sh=h;top_down=td;off=offset_arg;r0=requests;
 start();wait(done_seen || error_seen);repeat(6) @(negedge clk);
 if(error_seen || !done_seen || pixels!=dw*dh) $fatal(1,"image failed");
 $display("SCALE %dx%d orientation=%0d offset=%0d -> %dx%d, %0d pixels, %0d sectors, %0d cycles",sw,sh,top_down,off,dw,dh,pixels,requests-r0,cycles-start_cycle);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=0;scan_start=1;
 @(negedge clk);scan_start=0;
 wait(scan_done);repeat(3) @(negedge clk);
 if(found_total!=1 || found_count!=1) $fatal(1,"discovery");
 run_image(640,480,0,54);
 run_image(320,240,0,54);
 run_image(800,600,0,54);
 run_image(641,479,1,511); // odd padded width, top down, RGB crosses sectors
 run_image(1920,1080,0,4096);
 run_image(1,1,1,512); // extreme upscale, cache reuse and long backpressure
 dw=17;dh=13;
 run_image(2048,2048,0,54);
 run_image(2048,2048,1,54);
 run_image(1,2048,0,54);
 run_image(2048,1,0,54);
 run_image(7,5,1,54);
 for(bad=1;bad<=12;bad=bad+1) begin
     start();wait(done_seen || error_seen);repeat(5) @(negedge clk);
     if(!error_seen || done_seen || pixels!=0) $fatal(1,"accepted invalid header %d",bad);
 end
 bad=0;short_data=1;
 start();wait(error_seen);repeat(5) @(negedge clk);
 if(done_seen || pixels!=0) $fatal(1,"short sector leaked pixels");
 short_data=0;
 start();wait(pixels>20);@(negedge clk);abort_load=1;
 repeat(4) @(negedge clk);
 if(!ready || we || read || req || done) $fatal(1,"abort failed");
 abort_load=0;repeat(5) @(negedge clk);
 run_image(31,19,0,54);
 if(stalls==0) $fatal(1,"no backpressure tested");
 $display("PASS tb_bmp_scale: full-frame pixel comparisons, up/down/equal/odd/extreme sizes, signed height, padding, offsets, scan, backpressure, malformed/short/abort recovery");
 $finish;
end
endmodule
