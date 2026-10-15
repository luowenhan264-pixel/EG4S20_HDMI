module sd_eth_top(
      input  clk, 
      input  sys_rst_n,
      input  sd_miso , 
      output sd_clk  , 
      output sd_cs   , 
      output sd_mosi ,
        input               key1,    
        input               phy1_rgmii_rx_clk,
        input               phy1_rgmii_rx_ctl,
        input [3:0]         phy1_rgmii_rx_data,
        output wire         phy1_rgmii_tx_clk,
        output wire         phy1_rgmii_tx_ctl,
        output wire [3:0]   phy1_rgmii_tx_data,     
        output [2:0]        led
);


wire  key2;
assign key2 =sys_rst_n;
wire locked;
wire clk_50m ,clk_50m_180deg /* synthesis syn_keep=1 */;


wire abcdsfg ;//synthesis keep = 1
assign abcdsfg = 1;
wire clk_sample;//synthesis keep = 1
pll_50 u_pll_50(
  .refclk (clk)   ,
  .reset  ('b0)   ,
  .extlock(locked)  ,
  .clk0_out  (clk_50m),
  .clk1_out  (clk_50m_180deg),
  .clk2_out  (clk_sample)
);
wire rst_n/* synthesis syn_keep=1 */;
assign  rst_n = sys_rst_n & locked;    


wire sd_rd_start_en;
wire [31:0] sd_rd_sec_addr ;
wire sd_rd_busy;
wire sd_rd_val_en ,sd_init_done/* synthesis syn_keep=1 */;
wire [15:0] sd_rd_val_data;
wire sdr_wr_en;
wire [31:0]sdr_wr_data;
//SD卡顶层控制模块
sd_ctrl_top t1_sd_ctrl_top(
    .clk_ref                (clk_50m),
    .clk_ref_180deg         (clk_50m_180deg),
    .rst_n                  (rst_n),
    //SD卡接口
    .sd_miso                (sd_miso),
    .sd_clk                 (sd_clk),
    .sd_cs                  (sd_cs),
    .sd_mosi                (sd_mosi),
    // //用户写SD卡接口
    // .wr_start_en            (1'b0),                      //不需要写入数据,写入接口赋值为0
    // .wr_sec_addr            (32'b0),
    // .wr_data                (16'b0),
    // .wr_busy                (),
    // .wr_req                 (),
    // //用户读SD卡接口
    .rd_start_en            (sd_rd_start_en),
    .rd_sec_addr            (sd_rd_sec_addr),
    .rd_busy                (sd_rd_busy),
    .rd_val_en              (sd_rd_val_en),
    .rd_val_data            (sd_rd_val_data),    
    
    .sd_init_done           (sd_init_done)
    );  

wire Sdr_init_done/* synthesis syn_keep=1 */;
//读取SD卡图片
sd_read_photo t2_sd_read_photo(
    .clk                   (clk_50m),
    //系统初始化完成之后,再开始从SD卡中读取图片
    .rst_n                 (rst_n & Sdr_init_done & sd_init_done), 
    .ddr_max_addr          (24'd307200),       
    .sd_sec_num            (16'd1801), 
    .rd_busy               (sd_rd_busy),
    .sd_rd_val_en          (sd_rd_val_en),
    .sd_rd_val_data        (sd_rd_val_data),
    .rd_start_en           (sd_rd_start_en),
    .rd_sec_addr           (sd_rd_sec_addr),
    .sdr_wr_en             (sdr_wr_en),
    .sdr_wr_data           (sdr_wr_data)
    );     

wire Sdr_rd_en            ;//synthesis keep
wire [23:0] Sdr_rd_dout   ;//synthesis keep

sdram_top t3_sdram (
    .SYS_CLK                            (clk_50m                   ),
    // .LED                                (LED                       ),
    .sdr_data_valid                     (sdr_wr_en                 ),
    .sdr_data                           (sdr_wr_data               ),
    .rst_n                              (rst_n                     ),
    .Sdr_rd_en                          (Sdr_rd_en                 ),  
    .Sdr_rd_dout                        (Sdr_rd_dout               ) , 
    .Sdr_init_done                      (Sdr_init_done             ) 
    );

 udp_transmit_test t4_udp(
   .key1                (key1                )   ,
   .key2                (key2                )   ,
   .clk_25              (clk              )   ,                                                           //== 50M 

   .phy1_rgmii_rx_clk   (phy1_rgmii_rx_clk   )   ,
   .phy1_rgmii_rx_ctl   (phy1_rgmii_rx_ctl   )   ,
   .phy1_rgmii_rx_data  (phy1_rgmii_rx_data  )   ,
   .sd_tx_data_valid    (Sdr_rd_en    )   ,
   .sd_tx_data          (Sdr_rd_dout          )   ,
   .phy1_rgmii_tx_clk   (phy1_rgmii_tx_clk   )   ,
   .phy1_rgmii_tx_ctl   (phy1_rgmii_tx_ctl   )   ,
   .phy1_rgmii_tx_data  (phy1_rgmii_tx_data  )   
   // .led                 (led                 )   ,
   // .VGA_HSYNC           (VGA_HSYNC           )   ,
   // .VGA_VSYNC           (VGA_VSYNC           )   ,
   // .VGA_D               (VGA_D               )   
 );
endmodule
