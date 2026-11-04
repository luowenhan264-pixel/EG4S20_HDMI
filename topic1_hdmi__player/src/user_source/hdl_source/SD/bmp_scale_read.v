// FPGA nearest-neighbour BMP scaler. Output is TOP-DOWN RGB, destination size
// given by bmp_width/height (the board uses 640x480). Source: 1..2048 each axis,
// BITMAPINFOHEADER, uncompressed BGR24, either signed-height orientation.
// One 512-byte synchronous sector cache; no source-sized frame buffer or divider.
// Integer error accumulators implement floor(dst_x*src_w/dst_w), likewise y.
// pixel_ready is a write-clock-domain FIFO watermark, with >=2 cycles headroom.
module bmp_scale_read(
    input                       clk,
    input                       rst,
    output                      ready,

    // 上电扫描：从 scan_start_sector 开始，顺序寻找前 scan_target_count 张 BMP
    input                       scan_start,
    input  [31:0]               scan_start_sector,
    input  [31:0]               scan_max_sector,
    input  [2:0]                scan_target_count,
    output reg                  scan_done,
    output reg                  scan_found_valid,
    output reg [31:0]           scan_found_sector,
    output reg [2:0]            scan_found_total,

    // 按指定扇区加载一张图到 SDRAM
    input                       load_start,
    input                       load_abort,
    input  [31:0]               load_sector,
    output reg                  load_done,
    output reg                  load_error,

    input                       sd_init_done,
    output reg [3:0]            state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    output reg                  write_req,
    input                       write_req_ack,

    output reg                  sd_sec_read,
    output reg [31:0]           sd_sec_read_addr,
    input  [7:0]                sd_sec_read_data,
    input                       sd_sec_read_data_valid,
    input                       sd_sec_read_end,

    output reg                  bmp_data_wr_en,
    output reg [23:0]           bmp_data,
    input                       pixel_ready
);


localparam ST_IDLE=0, ST_SCAN=1, ST_LOAD_HDR=2, ST_LOAD_WAIT=3,
           ST_LOAD_DATA=4, ST_CHECK=5, ST_RAM_WAIT=6, ST_CAPTURE=7,
           ST_EMIT=8, ST_NEXT=9, ST_X_STEP=10, ST_Y_STEP=11,
           ST_ROW=12, ST_ADDRESS=13;
reg [3:0] state;
reg [9:0] rd_cnt;
reg [7:0] header_0, header_1;
reg [31:0] file_len, pixel_offset, width, height, compression, dib_size;
reg [15:0] bit_count, planes;
reg [1:0] ack_sync;
reg [31:0] scan_sector, load_sector_latched;
reg header_fields_valid;
reg [31:0] file_sector_count, next_scan_sector_if_match;
wire [31:0] next_scan_sector_if_miss = scan_sector + 32'd1;

reg [31:0] abs_height;
reg [13:0] row_stride;
reg [25:0] payload_bytes;
reg [31:0] pixel_end, first_row;
wire header_fields_match = header_0=="B" && header_1=="M" &&
    width>=1 && width<=2048 && abs_height>=1 && abs_height<=2048 &&
    bmp_width>=1 && bmp_width<=640 && bmp_height>=1 && bmp_height<=480 &&
    dib_size==40 && planes==1 && bit_count==24 && compression==0 &&
    pixel_offset>=54 && pixel_offset<=4096 &&
    file_len>=pixel_end && file_len<=32'h01000000;
wire header_match = header_fields_valid && rd_cnt==512;
assign ready = state==ST_IDLE;

// Header arithmetic is pipelined while the remaining header sector arrives.
always @(posedge clk or posedge rst) begin
    if(rst) begin
        abs_height<=0; row_stride<=0; payload_bytes<=0; pixel_end<=0; first_row<=0;
        header_fields_valid<=0; file_sector_count<=1; next_scan_sector_if_match<=0;
        ack_sync<=0;
    end else begin
        abs_height <= height[31] ? (~height+32'd1) : height;
        row_stride <= ( {2'b0,width[11:0]}*14'd3 + 14'd3 ) & 14'h3ffc;
        payload_bytes <= row_stride * abs_height[11:0];
        pixel_end <= pixel_offset + payload_bytes;
        first_row <= height[31] ? pixel_offset : pixel_end-row_stride;
        header_fields_valid <= header_fields_match;
        file_sector_count <= (file_len+32'd511)>>9;
        next_scan_sector_if_match <= scan_sector+file_sector_count;
        ack_sync <= {ack_sync[0],write_req_ack};
    end
end
always @(posedge clk or posedge rst) begin
    if(rst) rd_cnt<=0;
    else if(state==ST_SCAN || state==ST_LOAD_HDR || state==ST_LOAD_DATA) begin
        if(sd_sec_read_end) rd_cnt<=0;
        else if(sd_sec_read_data_valid) rd_cnt<=rd_cnt+1'b1;
    end else rd_cnt<=0;
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        header_0     <= 8'd0;
        header_1     <= 8'd0;
        file_len     <= 32'd0;
        pixel_offset <= 32'd54;
        width        <= 32'd0;
        height       <= 32'd0;
        bit_count    <= 16'd0;
        compression  <= 32'd0;
        dib_size     <= 0;
        planes       <= 0;
    end else if (((state == ST_SCAN) || (state == ST_LOAD_HDR)) && sd_sec_read_data_valid) begin
        case (rd_cnt)
            10'd0 : header_0 <= sd_sec_read_data;
            10'd1 : header_1 <= sd_sec_read_data;

            10'd2 : file_len[7:0] <= sd_sec_read_data;
            10'd3 : file_len[15:8] <= sd_sec_read_data;
            10'd4 : file_len[23:16] <= sd_sec_read_data;
            10'd5 : file_len[31:24] <= sd_sec_read_data;

            10'd10: pixel_offset[7:0] <= sd_sec_read_data;
            10'd11: pixel_offset[15:8] <= sd_sec_read_data;
            10'd12: pixel_offset[23:16] <= sd_sec_read_data;
            10'd13: pixel_offset[31:24] <= sd_sec_read_data;
            10'd14: dib_size[7:0] <= sd_sec_read_data;
            10'd15: dib_size[15:8] <= sd_sec_read_data;
            10'd16: dib_size[23:16] <= sd_sec_read_data;
            10'd17: dib_size[31:24] <= sd_sec_read_data;

            10'd18: width[7:0] <= sd_sec_read_data;
            10'd19: width[15:8] <= sd_sec_read_data;
            10'd20: width[23:16] <= sd_sec_read_data;
            10'd21: width[31:24] <= sd_sec_read_data;

            10'd22: height[7:0] <= sd_sec_read_data;
            10'd23: height[15:8] <= sd_sec_read_data;
            10'd24: height[23:16] <= sd_sec_read_data;
            10'd25: height[31:24] <= sd_sec_read_data;
            10'd26: planes[7:0] <= sd_sec_read_data;
            10'd27: planes[15:8] <= sd_sec_read_data;

            10'd28: bit_count[7:0] <= sd_sec_read_data;
            10'd29: bit_count[15:8] <= sd_sec_read_data;

            10'd30: compression[7:0] <= sd_sec_read_data;
            10'd31: compression[15:8] <= sd_sec_read_data;
            10'd32: compression[23:16] <= sd_sec_read_data;
            10'd33: compression[31:24] <= sd_sec_read_data;
            default: ;
        endcase
    end
end


reg [7:0] sector_cache [0:511];
reg [7:0] cache_q;
reg cache_valid;
reg [22:0] cache_tag;
reg [31:0] byte_addr, row_addr;
reg [13:0] x_byte;
reg [12:0] x_error, y_error;
reg [9:0] out_x, out_y;
reg [1:0] component;
// No reset on the RAM: invalidate its tag instead, allowing BRAM inference.
always @(posedge clk) begin
    if(state==ST_LOAD_DATA && sd_sec_read_data_valid && rd_cnt<512)
        sector_cache[rd_cnt[8:0]] <= sd_sec_read_data;
    cache_q <= sector_cache[byte_addr[8:0]];
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state<=ST_IDLE; state_code<=0; sd_sec_read<=0; sd_sec_read_addr<=0;
        write_req<=0; scan_done<=0; scan_found_valid<=0; scan_found_sector<=0;
        scan_found_total<=0; scan_sector<=0; load_sector_latched<=0;
        load_done<=0; load_error<=0; bmp_data_wr_en<=0; bmp_data<=0;
        cache_valid<=0; cache_tag<=0; byte_addr<=0; row_addr<=0;
        x_byte<=0; x_error<=0; y_error<=0; out_x<=0; out_y<=0; component<=0;
    end else if(!sd_init_done || load_abort) begin
        state<=ST_IDLE; state_code<=0; sd_sec_read<=0; write_req<=0;
        scan_done<=0; scan_found_valid<=0; scan_found_total<=0;
        load_done<=0; load_error<=0; bmp_data_wr_en<=0; cache_valid<=0;
    end else begin
        scan_found_valid<=0; load_done<=0; load_error<=0; bmp_data_wr_en<=0;
        case(state)
        ST_IDLE: begin
            state_code<=1; sd_sec_read<=0; write_req<=0;
            if(scan_start && scan_target_count!=0 && scan_start_sector<=scan_max_sector) begin
                scan_done<=0; scan_found_total<=0; scan_sector<=scan_start_sector;
                sd_sec_read_addr<=scan_start_sector; state<=ST_SCAN;
            end else if(load_start) begin
                load_sector_latched<=load_sector; sd_sec_read_addr<=load_sector;
                cache_valid<=0; state<=ST_LOAD_HDR;
            end
        end
        ST_SCAN: begin
            state_code<=2; sd_sec_read<=1;
            if(sd_sec_read_end) begin
                sd_sec_read<=0;
                if(header_match) begin
                    scan_found_valid<=1; scan_found_sector<=scan_sector;
                    scan_found_total<=scan_found_total+1'b1;
                    if(scan_found_total+3'd1>=scan_target_count ||
                       next_scan_sector_if_match>scan_max_sector ||
                       next_scan_sector_if_match<scan_sector) begin
                        scan_done<=1; state<=ST_IDLE;
                    end else begin
                        sd_sec_read_addr<=next_scan_sector_if_match;
                        scan_sector<=next_scan_sector_if_match;
                    end
                end else if(scan_sector>=scan_max_sector) begin
                    scan_done<=1; state<=ST_IDLE;
                end else begin
                    sd_sec_read_addr<=next_scan_sector_if_miss;
                    scan_sector<=next_scan_sector_if_miss;
                end
            end
        end
        ST_LOAD_HDR: begin
            state_code<=2; sd_sec_read<=1;
            if(sd_sec_read_end) begin
                sd_sec_read<=0;
                if(header_match) begin
                    write_req<=1; state<=ST_LOAD_WAIT;
                    row_addr<=first_row; byte_addr<=first_row;
                    out_x<=0; out_y<=0; x_byte<=0; x_error<=0; y_error<=0; component<=0;
                end else begin load_error<=1; state<=ST_IDLE; end
            end
        end
        ST_LOAD_WAIT: begin
            state_code<=3;
            if(ack_sync[1]) begin write_req<=0; state<=ST_CHECK; end
        end
        ST_CHECK: begin
            state_code<=4;
            if(cache_valid && cache_tag==byte_addr[31:9]) state<=ST_RAM_WAIT;
            else begin
                cache_valid<=0; cache_tag<=byte_addr[31:9];
                sd_sec_read_addr<=load_sector_latched+{9'b0,byte_addr[31:9]};
                state<=ST_LOAD_DATA;
            end
        end
        ST_LOAD_DATA: begin
            sd_sec_read<=1;
            if(sd_sec_read_end) begin
                sd_sec_read<=0;
                if(rd_cnt!=512 || sd_sec_read_addr<load_sector_latched) begin
                    load_error<=1; state<=ST_IDLE;
                end else begin cache_valid<=1; state<=ST_CHECK; end
            end
        end
        ST_RAM_WAIT: state<=ST_CAPTURE;
        ST_CAPTURE: begin
            case(component)
                0: bmp_data[7:0]<=cache_q;
                1: bmp_data[15:8]<=cache_q;
                2: bmp_data[23:16]<=cache_q;
            endcase
            if(component==2) state<=ST_EMIT;
            else begin component<=component+1'b1; byte_addr<=byte_addr+1'b1; state<=ST_CHECK; end
        end
        ST_EMIT: if(pixel_ready) begin
            bmp_data_wr_en<=1; state<=ST_NEXT;
        end
        ST_NEXT: begin
            component<=0;
            if(out_x==bmp_width-1'b1) begin
                out_x<=0; x_byte<=0; x_error<=0;
                if(out_y==bmp_height-1'b1) begin load_done<=1; state<=ST_IDLE; end
                else begin
                    out_y<=out_y+1'b1; y_error<=y_error+abs_height[11:0]; state<=ST_Y_STEP;
                end
            end else begin
                out_x<=out_x+1'b1; x_error<=x_error+width[11:0]; state<=ST_X_STEP;
            end
        end
        ST_X_STEP: begin
            if(x_error>=bmp_width) begin x_error<=x_error-bmp_width; x_byte<=x_byte+14'd3; end
            else state<=ST_ADDRESS;
        end
        ST_Y_STEP: begin
            if(y_error>=bmp_height) begin
                y_error<=y_error-bmp_height;
                row_addr<=height[31] ? row_addr+row_stride : row_addr-row_stride;
            end else state<=ST_ROW;
        end
        ST_ROW: begin byte_addr<=row_addr; state<=ST_CHECK; end
        ST_ADDRESS: begin byte_addr<=row_addr+x_byte; state<=ST_CHECK; end
        default: begin state<=ST_IDLE; load_error<=1; sd_sec_read<=0; write_req<=0; end
        endcase
    end
end
endmodule
