`timescale 1ns/1ps
module tb_audio_link;
reg video_clk=0, mclk=0;
always #20 video_clk=~video_clk;
always #40.667 mclk=~mclk;
reg rst=1, frame_start=0, request=0;
reg [1:0] requested_bank=0, requested_image=0;
wire ack,valid,event_toggle,bclk,lrck,dout,audio_valid;
wire [1:0] bank,image_id,event_image;
wire [5:0] gain;
wire [23:0] left_pcm,right_pcm;
player_frame_commit commit(video_clk,rst,frame_start,request,
    requested_bank,requested_image,ack,bank,image_id,valid,gain,);
player_picture_event events(video_clk,rst,valid,bank,image_id,event_toggle,event_image,1'b0,);
hdmi_audio_link_i2s #(.CUE_SAMPLES(1024)) cue(mclk,rst,event_toggle,event_image,bclk,lrck,dout,2'd3,1'b0);
I2S_receiver receiver(video_clk,rst,bclk,lrck,dout,audio_valid,left_pcm,right_pcm);
integer total_samples=0;
integer last_sample_time=0;
reg check_stream=0;
always @(posedge video_clk) begin
    #1;
    if(audio_valid && check_stream) begin
        total_samples=total_samples+1;
        if(left_pcm!==right_pcm) $fatal(1,"stereo mismatch: %h %h",left_pcm,right_pcm);
        if($isunknown(left_pcm)) $fatal(1,"unknown PCM");
        if(last_sample_time && ($time-last_sample_time<20700 || $time-last_sample_time>20900))
            $fatal(1,"audio sample cadence changed: %0t",$time-last_sample_time);
        last_sample_time=$time;
    end
end
task next_sample;
 begin
    @(posedge video_clk); #2;
    while(!audio_valid) begin @(posedge video_clk); #2; end
 end
endtask
task frame;
 begin
    @(negedge video_clk);frame_start=1;
    @(negedge video_clk);frame_start=0;
    repeat(8) @(negedge video_clk);
 end
endtask
task finish_fade;
 integer k;
 begin for(k=0;k<32;k=k+1) frame();
    if(ack!==request) $fatal(1,"fade ACK missing");
 end
endtask
task switch_picture(input [1:0] id);
 integer k;
 reg old_event;
 begin
    old_event=event_toggle;
    @(negedge video_clk);
    requested_bank=~requested_bank & 2'b01;
    requested_image=id;request=~request;
    repeat(8) @(negedge video_clk);
    if(event_toggle!==old_event) $fatal(1,"sound on uncommitted request");
    frame();
    if(valid && gain==32) begin
        for(k=0;k<32;k=k+1) begin
            frame();
            if(event_toggle!==old_event) $fatal(1,"cue during old-picture fade-out");
        end
        frame();
    end
    if(gain!=0 || event_toggle===old_event || event_image!=id)
        $fatal(1,"cue not aligned with black bank swap");
 end
endtask
task measure_cue(input integer expected_crossings);
 integer k,nonzero,crossings,first_nonzero,pcm,previous,peak;
 begin
    nonzero=0;crossings=0;first_nonzero=-1;previous=0;peak=0;
    for(k=0;k<1032;k=k+1) begin
        next_sample();pcm=$signed(left_pcm);
        if(pcm!=0) begin
            nonzero=nonzero+1;
            if(first_nonzero<0) first_nonzero=k;
            if((pcm<0 && previous>0)||(pcm>0 && previous<0)) crossings=crossings+1;
            previous=pcm;
            if(pcm>peak) peak=pcm;
        end
        if(pcm>500000 || pcm< -500000) $fatal(1,"PCM amplitude overflow");
    end
    if(first_nonzero<0 || first_nonzero>5 || nonzero<1010 || nonzero>1024)
        $fatal(1,"cue duration/latency: first=%0d samples=%0d",first_nonzero,nonzero);
    if(crossings<expected_crossings-1 || crossings>expected_crossings+1)
        $fatal(1,"wrong picture pitch: expected ~%0d crossings, got %0d",expected_crossings,crossings);
    if(peak<490000 || left_pcm!=0) $fatal(1,"envelope or end silence");
    $display("cue checked: %0d nonzero samples, %0d sign changes",nonzero,crossings);
    finish_fade();
    for(k=0;k<12;k=k+1) begin next_sample(); if(left_pcm!=0) $fatal(1,"cue repeated without a commit"); end
 end
endtask
integer k;
initial begin
    repeat(10) @(negedge video_clk);rst=0;
    repeat(5) next_sample();check_stream=1;
    for(k=0;k<12;k=k+1) begin next_sample();if(left_pcm!=0) $fatal(1,"startup is not silent");end
    switch_picture(0);measure_cue(11);
    switch_picture(1);measure_cue(14);
    switch_picture(2);measure_cue(16);
    switch_picture(3);measure_cue(22);
    // A new commit while a cue is active restarts the short sound cleanly.
    switch_picture(0);finish_fade();repeat(20) next_sample();
    switch_picture(3);measure_cue(22);
    switch_picture(2);repeat(15) next_sample();
    check_stream=0;last_sample_time=0;rst=1;
    repeat(10) @(negedge video_clk);rst=0;
    repeat(5) next_sample();check_stream=1;
    for(k=0;k<20;k=k+1) begin next_sample();if(left_pcm!=0) $fatal(1,"stale cue after reset");end
    $display("PASS tb_audio_link: real commit/fade + CDC + serializer + receiver, four pitches, stereo, duration, continuous silence, retrigger, reset");
    $finish;
end
initial begin #200000000;$fatal(1,"watchdog");end
endmodule
