module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
	 
    output  reg                      awready,
    output  reg                      wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
	 
	 
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  reg                      rvalid,
    output  reg [(pDATA_WIDTH-1):0]  rdata, 
	 
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
	 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  reg [3:0]                tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  reg [3:0]                data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

    // write your code here!
	
	localparam  IDLE 		 = 3'b000,
					RD_LEN    = 3'b001, 
					RD_TAP    = 3'b011, 
					CK_TAP    = 3'b010,
					RD_Xn     = 3'b110, 
					MUL_ADD   = 3'b111,
					TRANS_Yn  = 3'b101,
					DONE 		 = 3'b100;
					
					
	reg [2:0]state,next_state;
	
	reg [(pDATA_WIDTH-1):0]len_store;
	reg [(pDATA_WIDTH-1):0]len;
	reg [3:0]TAP_BRAM_addr;
	reg [3:0]DATA_BRAM_addr;
	reg [3:0]DATA_start_addr;
	reg [(pDATA_WIDTH-1):0]acc;
	
	
	reg [(pDATA_WIDTH-1):0]len_mux;
	wire len_en; 
	reg  [3:0]tap_addr_mux;
	reg  [3:0]data_addr_mux;
	wire data_addr_wen;
	wire tap_addr_wen;
	wire [(pDATA_WIDTH-1):0]data_BRAM_Di;
	wire [(pDATA_WIDTH-1):0]mul_out;
	wire [(pDATA_WIDTH-1):0]adder_sle_0;
	wire [(pDATA_WIDTH-1):0]adder_sle_1;
	wire [(pDATA_WIDTH-1):0]adder_out;
	wire [(pDATA_WIDTH-1):0]acc_mux;
	wire acc_en;
	
	//assign len_mux = len_mux_sle ? wdata : adder_out;
	//assign len_mux_sle = state == RD_LEN ? 1'd1 : 1'd0;
	
	assign len_en = (state == RD_LEN && wvalid) 
					 || (state == TRANS_Yn && sm_tready == 1'd1
					 || (state == DONE));
	
	assign tap_addr_wen = (state == RD_TAP && awvalid == 1'd1 && wvalid == 1'd1) 
							 || (state == CK_TAP && arvalid == 1'd1)
							 || (state == MUL_ADD && ss_tvalid == 1'd1
							 || state == IDLE);
							 
	assign data_addr_wen = (state == RD_TAP && awvalid == 1'd1 && wvalid == 1'd1)
						     || (state == CK_TAP && arvalid == 1'd1)
							  || (state == RD_Xn && ss_tvalid == 1'd1)
							  || (state == MUL_ADD && ss_tvalid == 1'd1)
							  || (state == TRANS_Yn && sm_tready == 1'd1 && len == 32'd1)
							  || (state == DONE)
							  || (state == IDLE);
	
	assign data_BRAM_Di = state == RD_Xn ? ss_tdata : 32'd0;
	
	assign mul_out = data_Do * tap_Do;
	assign adder_sle_0 = state == MUL_ADD ? mul_out : len;
	assign adder_sle_1 = state == MUL_ADD ? acc : 'hffff_ffff;
	assign adder_out = adder_sle_0 + adder_sle_1;
	
	assign acc_mux = state == RD_Xn ? 32'd0 : adder_out;
	assign acc_en = state == RD_Xn || (state == MUL_ADD && ss_tvalid == 1'd1) || (state == TRANS_Yn && sm_tready == 1'd1);
	
	///////// output BRAM /////////
   assign tap_EN = 1;
   assign tap_Di = wdata;
   assign tap_A = TAP_BRAM_addr << 2;
	
   assign data_EN = 1;
   assign data_Di = data_BRAM_Di;
   assign data_A = DATA_BRAM_addr << 2;
	///////// output BRAM /////////
	
	///////// output /////////
	/*assign rvalid = (state == CK_TAP && arvalid == 1'd1)
					 || (state == DONE && arvalid == 1'd1 && DATA_BRAM_addr == 4'd0) 
					 || (state == IDLE && arvalid == 1'd1) ? 1'd1 : 1'd0;*/
					 
	assign arready = (state == CK_TAP && arvalid == 1'd1) || (state == DONE && arvalid == 1'd1)? 1'd1 : 1'd0;
	
	//assign rdata = state == IDLE ? 32'd4 : (state == DONE ? 32'd2 : tap_Do);
	
	assign ss_tready = state == RD_Xn && ss_tvalid == 1'd1 ? 1'd1 : 1'd0;
	
	assign sm_tvalid = state == TRANS_Yn ? 1'd1 : 1'd0;
   assign sm_tdata = acc;
   assign sm_tlast = ((state == TRANS_Yn || state == MUL_ADD) && len == 'd1) ? 1'd1 : 1'd0;
	///////// output /////////
	
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			state <= IDLE;
		else
			state <= next_state;
	end
	
	always@(*)begin
		case(state)
			IDLE 		 :begin
				if(awvalid == 1'd1)
					case(awaddr)
						'h00: next_state = (wvalid == 1'd1 && wdata[0] == 1'd1) ? RD_Xn : IDLE;
						'h10: next_state = RD_LEN;
						'h80: next_state = RD_TAP;
						default: next_state = IDLE;
					endcase
				else begin
					next_state = IDLE;
				end
			end
			RD_LEN    : next_state = wvalid == 1'd1 ? IDLE : RD_LEN;
			RD_TAP    : next_state = (awvalid == 1'd1 && awaddr == 'ha8) ? CK_TAP : RD_TAP;
			CK_TAP    : next_state = (araddr == 'ha8 && arvalid == 1'd1)? IDLE : CK_TAP;
			RD_Xn     : next_state = ss_tvalid == 1'd1 ? MUL_ADD : RD_Xn;
			MUL_ADD   : next_state = DATA_start_addr == DATA_BRAM_addr ? TRANS_Yn : MUL_ADD;
			TRANS_Yn  :begin
				if(sm_tready == 1'd1)
					next_state = len == 32'd1 ? DONE : RD_Xn;
				else 
					next_state = TRANS_Yn;
			end		
			DONE : next_state = (DATA_BRAM_addr == 4'd1) ? IDLE : DONE;
			default   : next_state = IDLE;
		endcase
	end
	
	always@(*)begin
		if(state == IDLE)begin
			tap_addr_mux = 4'd0;
		end
		else begin
			case(TAP_BRAM_addr)
				4'd0 : tap_addr_mux = 4'd1;
				4'd1 : tap_addr_mux = 4'd2;
				4'd2 : tap_addr_mux = 4'd3;
				4'd3 : tap_addr_mux = 4'd4;
				4'd4 : tap_addr_mux = 4'd5;
				4'd5 : tap_addr_mux = 4'd6;
				4'd6 : tap_addr_mux = 4'd7;
				4'd7 : tap_addr_mux = 4'd8;
				4'd8 : tap_addr_mux = 4'd9;
				4'd9 : tap_addr_mux = 4'd10;
				4'd10: tap_addr_mux = 4'd0;
				default: tap_addr_mux = 4'd0;
			endcase
		end
	end
	
	always@(*)begin
		if((state == TRANS_Yn && sm_tready == 1'd1 && len == 32'd1) || state == IDLE)begin
			data_addr_mux = 4'd0;
		end
		else begin
			case(DATA_BRAM_addr)
				4'd0 : data_addr_mux = 4'd10;
				4'd1 : data_addr_mux = 4'd0;
				4'd2 : data_addr_mux = 4'd1;
				4'd3 : data_addr_mux = 4'd2;
				4'd4 : data_addr_mux = 4'd3;
				4'd5 : data_addr_mux = 4'd4;
				4'd6 : data_addr_mux = 4'd5;
				4'd7 : data_addr_mux = 4'd6;
				4'd8 : data_addr_mux = 4'd7;
				4'd9 : data_addr_mux = 4'd8;
				4'd10: data_addr_mux = 4'd9;
				default: data_addr_mux = 4'd0;
			endcase
		end
	end
	
	always@(*)begin
		case(state)
			IDLE      : awready = awvalid == 1'd1 && wvalid == 1'd1 && wdata[0] == 1'd1 && awaddr == 'h00 ? 1'd1 : 1'd0; 
			RD_LEN    : awready = 1'd1;
			RD_TAP    : awready = 1'd1;
			default   : awready = 1'd0;
		endcase
	end
	
	always@(*)begin
		case(state)
		   IDLE      : wready = awvalid == 1'd1 && wvalid == 1'd1 && wdata[0] == 1'd1 && awaddr == 'h00 ? 1'd1 : 1'd0; 
			RD_LEN    : wready = 1'd1;
			RD_TAP    : wready = 1'd1;
			default   : wready = 1'd0;
		endcase
	end
	
	
	always@(*)begin
		case(state)
			RD_TAP    : tap_WE = awvalid == 1'd1 && wvalid == 1'd1 ? 4'b1111 : 4'b0000;
			default   : tap_WE = 4'b0000;
		endcase
	end
	
	always@(*)begin
		case(state)
			RD_TAP    : data_WE = awvalid == 1'd1 && wvalid == 1'd1 ? 4'b1111 : 4'b0000;
			RD_Xn     : data_WE = ss_tvalid == 1'd1 ? 4'b1111 : 4'b0000;
			DONE		 : data_WE = 4'b1111;
			default   : data_WE = 4'b0000;
		endcase
	end
	
	always@(*)begin
		case(state)
			RD_LEN    : len_mux = wdata;
			DONE      : len_mux = len_store;
			default   : len_mux = adder_out;
		endcase
	end
	
	always@(*)begin
		case(state)
			IDLE      : rdata = 32'd4;
			DONE      : rdata = 32'd2;
			RD_Xn     : rdata = 32'd0;
			MUL_ADD   : rdata = 32'd0;
			TRANS_Yn  : rdata = 32'd0;
			default   : rdata = tap_Do;
		endcase
	end
	
	always@(*)begin
		case(state)
			CK_TAP    : rvalid = arvalid == 1'd1 ? 1'd1 : 1'd0;
			DONE      : rvalid = (arvalid == 1'd1) && (DATA_BRAM_addr == 4'd2) ? 1'd1 : 1'd0;
			IDLE      : rvalid = arvalid == 1'd1 ? 1'd1 : 1'd0;
			MUL_ADD   : rvalid = arvalid == 1'd1 && len != 32'd1 ? 1'd1 : 1'd0;
			default   : rvalid = 1'd0;
		endcase
	end
	

	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			len <= 32'd0;
		else
			len <= len_en ? len_mux : len;
	end
	
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			len_store <= 32'd0;
		else
			len_store <= state == RD_LEN && wvalid ? wdata : len_store;
	end
	
	
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			TAP_BRAM_addr <= 4'd0;
		else
			TAP_BRAM_addr <= tap_addr_wen ? tap_addr_mux : TAP_BRAM_addr;
	end
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			DATA_BRAM_addr <= 4'd0;
		else
			DATA_BRAM_addr <= data_addr_wen ? data_addr_mux : DATA_BRAM_addr;
	end
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0)
			acc <= 32'd0;
		else
			acc <= acc_en ? acc_mux : acc;
	end
	
	always@(posedge axis_clk or negedge axis_rst_n)begin
		if(axis_rst_n == 1'b0 || state == IDLE)
			DATA_start_addr <= 4'd0;
		else
			DATA_start_addr <= state == RD_Xn ? DATA_BRAM_addr : DATA_start_addr;
	end
	
	
	
	

endmodule

