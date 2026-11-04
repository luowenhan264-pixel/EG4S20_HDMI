`timescale 1ns/1ps
module tb_settings_osd;
reg clk=0,rst=1,hs=0,vs=1,de=0,menu=0;
always #20 clk=~clk;
wire ho,vo,dout;wire [23:0] rgb;
player_settings_osd dut(clk,rst,hs,vs,de,24'h234567,menu,3'd1,2'd1,2'd2,1'b1,ho,vo,dout,rgb,4'd4,3'd2,1'b0,2'd0);
integer x,y,f,pass;
initial begin
 repeat(4)@(negedge clk);rst=0;
 f=$fopen("settings_menu.ppm","w");$fwrite(f,"P3\n640 80\n255\n");
 for(pass=0;pass<2;pass=pass+1) begin
   menu=pass;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
   for(y=0;y<80;y=y+1) begin
     for(x=0;x<640;x=x+1) begin
       de=1;hs=x[0];@(posedge clk);#1;
       if(!dout || ho!==hs || vo!==vs)$fatal(1,"sync alignment");
       if(!menu && rgb!=24'h234567)$fatal(1,"closed menu is not transparent");
       if(menu) begin
         if(y==36 && x==8 && rgb!=24'he0e0e0)$fatal(1,"T text/coordinate");
         if(y==36 && x==152 && rgb!=24'hffff00)$fatal(1,"selected V highlight");
         if(y==36 && x==218 && rgb!=24'hffff00)$fatal(1,"volume digit 2");
         if(y==36 && x==18 && rgb!=24'h101828)$fatal(1,"text spacing background");
         if((x<8 || x>=360 || !((y>=36 && y<54)||(y>=60 && y<78))) && rgb!=24'h234567)$fatal(1,"overlay bounds");
         $fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
       end
       @(negedge clk);
     end
     de=0;@(posedge clk);#1;if(dout || rgb!=0)$fatal(1,"blanking");
     repeat(4)@(negedge clk);
   end
 end
 $fclose(f);$display("PASS tb_settings_osd: readable values/highlight, bounds, closed passthrough, sync/DE, pixel render");$finish;
end
initial begin #10000000;$fatal(1,"watchdog");end
endmodule
