module IPF ( clk, reset, in_en, din, ipf_type, ipf_band_pos, ipf_wo_class, ipf_offset, lcu_x, lcu_y, lcu_size, busy, out_en, dout, dout_addr, finish);
input   clk;
input   reset;
input   in_en;
input   [7:0]  din;
input   [1:0]  ipf_type;
input   [4:0]  ipf_band_pos;
input          ipf_wo_class;
input   [15:0] ipf_offset;
input   [2:0]  lcu_x;
input   [2:0]  lcu_y;
input   [1:0]  lcu_size;
output  busy;
output  finish;
output  out_en;
output  [7:0] dout;
output  [13:0] dout_addr;


// FSM for top module
parameter S_INIT = 4'd0;
parameter S_OFF = 4'd1;
parameter S_PO = 4'd2;
parameter S_WO_HORI = 4'd3;
parameter S_WO_VERT = 4'd4;
reg [3:0] c_state, n_state;

// FSM for WO horizontal
parameter S_WO_H_INIT     = 3'd0;
parameter S_WO_H_IN1      = 3'd1;
parameter S_WO_H_IN2      = 3'd2;
parameter S_WO_H_CAL      = 3'd3;
parameter S_WO_H_ENDR1    = 3'd4; // End of row
parameter S_WO_H_ENDR2    = 3'd5; // End of row
parameter S_WO_H_ENDU1    = 3'd6; // End of LCU
parameter S_WO_H_ENDU2    = 3'd7; // End of LCU
reg [2:0] c_wo_h_state, n_wo_h_state;

// Buffer for WO horizontal
reg [7:0] c_buffer [2:0];
reg [7:0] n_buffer [2:0];

// buffer for WO vertical
// TODO: reg [7:0] c_buffer_xl [];
// TODO: reg [7:0] c_buffer_xl [];


//wire/reg declaration

// Input
reg c_in_en, n_in_en;
reg [7:0] c_din, n_din;
reg [1:0] c_ipf_type, n_ipf_type;
reg [4:0] c_ipf_band_pos, n_ipf_band_pos;
reg c_ipf_wo_class, n_ipf_wo_class;
reg [15:0] c_offset, n_offset;
//wire [3:0] offset [0:3] = c_offset[15:0];

wire [3:0] offset0 = c_offset[15:12];
wire [3:0] offset1 = c_offset[11:8];
wire [3:0] offset2 = c_offset[7:4];
wire [3:0] offset3 = c_offset[3:0];


reg [2:0] c_lcu_x, n_lcu_x;
reg [2:0] c_lcu_y, n_lcu_y;
reg [6:0] c_lcu_size, n_lcu_size; //the size of 1 lcu (16x16, 32x32, 64x64) but here it is 15, 31, 63 since we start from 0

// Output
reg c_busy, n_busy;
reg c_finish, n_finish;
reg c_out_en, n_out_en;
reg [7:0] c_dout, n_dout;
//------Input and Output register


//act as counter for row and column pixel. This will be use full to access index and to check whether the system have finished or not
reg [6:0] c_in_x, n_in_x, c_in_y, n_in_y; 
reg [6:0] c_out_x, n_out_x, c_out_y, n_out_y;
reg [2:0] c_max_lcu, n_max_lcu; //the maximum coordinate of lcu_x and lcu_y
//------- Some new variable that will needed

reg c_lcu_finish, n_lcu_finish;

assign busy = c_busy;
assign finish = c_finish;
assign out_en = c_out_en;
assign dout = c_dout;
wire [4:0] band_index = c_din / 4'd8;

DoutAddrCtrl doutAddrCtrl (
    .clk(clk),
    .reset(reset),
    .block_size(c_lcu_size),
    .block_x(c_lcu_x),
    .block_y(c_lcu_y),
    .pixel_x(c_out_x),
    .pixel_y(c_out_y),
    .dout_addr(dout_addr)
    // TODO: Check if the wiring makes sense
);


//WOVertCalc woVertCalc (.*);

reg [7:0] c_band_idx, n_band_idx;

//------Combinational Part
always@(*) begin
    case(c_state)
    S_INIT: begin
        if (in_en) begin
            if(ipf_type == 0) begin
                n_state = S_OFF;
            end
            else if(ipf_type == 1) begin
                n_state = S_PO;
            end
            else begin
                n_state = S_OFF;
                /*
                if (ipf_wo_class == 0) begin
                    n_state = S_WO_HORI;
                end
                else begin
                    n_state = S_WO_VERT;
                end
                */
            end
        end
        else begin
            n_state = S_INIT;
        end
        // TODO: State transition
        n_wo_h_state = c_wo_h_state;
        n_busy = 1'b0;
        n_out_en = 1'b0;
        n_in_x = 7'd0;
        n_in_y = 7'd0;
        n_out_x = 7'd0;
        n_out_y = 7'd0;
        n_lcu_finish = 1'b0;
        n_dout = c_dout;
        n_buffer[2] = c_buffer[2];
        n_buffer[1] = c_buffer[1];
        n_buffer[0] = c_buffer[0];
    end
    S_OFF: begin
        n_state = !(c_in_y == c_lcu_size + 1) ? S_OFF : S_INIT;
        n_wo_h_state = c_wo_h_state;
        n_busy = (c_in_y == c_lcu_size + 1) ||
                ((c_in_y == c_lcu_size) && (c_in_x == c_lcu_size)); // TODO: Check correctness
        n_out_en = !(c_in_y == (c_lcu_size + 1));
        n_in_x = (c_in_x == c_lcu_size) ? 7'd0 : (c_in_x + 7'd1);
        n_in_y = (c_in_y == c_lcu_size + 1) ? 7'd0
                        : (c_in_x == c_lcu_size) ? (c_in_y + 7'd1)
                        : c_in_y;
        n_out_x = n_in_x;
        n_out_y = n_in_y;
        n_dout = c_din;
        n_buffer[2] = c_buffer[2];
        n_buffer[1] = c_buffer[1];
        n_buffer[0] = c_buffer[0];
    end
    S_PO: begin
        n_state = !(c_in_y == c_lcu_size + 1) ? S_PO : S_INIT;
        n_wo_h_state = c_wo_h_state;
        n_busy = (c_in_y == c_lcu_size + 1) ||
                ((c_in_y == c_lcu_size) && (c_in_x == c_lcu_size)); // TODO: Check correctness
        n_out_en = !(c_in_y == (c_lcu_size + 1));
        n_in_x = (c_in_x == c_lcu_size) ? 7'd0 : (c_in_x + 7'd1);
        n_in_y = (c_in_y == c_lcu_size + 1) ? 7'd0
                                        : (c_in_x == c_lcu_size) ? (c_in_y + 7'd1)
                                        : c_in_y;
        n_out_x = n_in_x;
        n_out_y = n_in_y;
        if ((c_band_idx == c_ipf_band_pos) ||
            (c_band_idx == c_ipf_band_pos - 1) ||
            (c_band_idx == c_ipf_band_pos + 1)) begin
            n_dout = c_din;
        end
        else if((c_band_idx % 4) == 2'd0) begin
            n_dout = (c_din + offset0 > 8'd255) ? 8'd255 : c_din + offset0;
        end
        else if((c_band_idx % 4) == 2'd1) begin
            n_dout = (c_din + offset1 > 8'd255) ? 8'd255 : c_din + offset1;
        end
        else if((c_band_idx % 4) == 2'd2) begin
            n_dout = ($signed({1'b0,c_din}) +  $signed(offset2) < 8'd0) ? $signed(8'd0) : $signed({1'b0,c_din}) + $signed(offset2);
        end
        else begin
            n_dout = ($signed({1'b0,c_din}) +  $signed(offset3) < 8'd0) ? $signed(8'd0) : $signed({1'b0,c_din}) + $signed(offset3);
        end 
        n_buffer[2] = c_buffer[2];
        n_buffer[1] = c_buffer[1];
        n_buffer[0] = c_buffer[0];
    end
    S_WO_HORI: begin
        n_state = (c_wo_h_state == S_WO_H_ENDU2) ? S_INIT : S_WO_HORI;
        case (c_wo_h_state)
        S_WO_H_INIT: begin
            n_wo_h_state = S_WO_H_IN1;
            n_busy = 1'b0;
            n_out_en = 1'b0;
            n_in_x = 7'd1;
            n_in_y = c_in_y;
            n_out_x = c_out_x;
            n_out_y = c_out_y;
            n_dout = 7'b0;
            n_buffer[2] = 0;
            n_buffer[1] = 0;
            n_buffer[0] = c_din;
        end
        S_WO_H_IN1: begin
            n_wo_h_state = S_WO_H_IN2;
            n_busy = 1'b0;
            n_out_en = 1'b0;
            n_in_x = 7'd2;
            n_in_y = c_in_y;
            n_out_x = 0;
            n_out_y = c_in_y;
            n_dout = c_dout;
            n_buffer[2] = c_buffer[1];
            n_buffer[1] = c_buffer[0];
            n_buffer[0] = c_din;
        end
        S_WO_H_IN2: begin
            n_wo_h_state = S_WO_H_CAL;
            n_busy = 1'b0;
            n_out_en = 1'b1;
            n_in_x = c_in_x + 1;
            n_in_y = c_in_y;
            n_out_x = c_out_x + 1;
            n_out_y = c_out_y;
            n_dout = c_buffer[1];
            n_buffer[2] = c_buffer[1];
            n_buffer[1] = c_buffer[0];
            n_buffer[0] = c_din;
        end
        S_WO_H_CAL: begin
            // TODO: finish this state
            if (c_in_x != c_lcu_size) begin
                n_wo_h_state = S_WO_H_CAL;
            end
            else if (c_in_y != c_lcu_size) begin
                n_wo_h_state = S_WO_H_ENDR1;
            end
            else begin
                n_wo_h_state = S_WO_H_ENDU1;
            end
            if ((c_in_x == c_lcu_size - 1) ||
                (c_in_x == c_lcu_size)) begin
                n_busy = 1'b1;                
            end
            else begin
                n_busy = 1'b0;
            end
            n_out_en = 1'b1;
            n_in_x = c_in_x + 1;
            n_in_y = c_in_y;
            n_out_x = c_out_x + 1;
            n_out_y = c_out_y;
            n_dout = c_buffer[1] + offset0; // TODO: choose offset
            n_buffer[2] = c_buffer[1];
            n_buffer[1] = c_buffer[0];
            n_buffer[0] = c_din;
        end
        S_WO_H_ENDR1: begin
            n_wo_h_state = S_WO_H_ENDR2;
            n_busy = 1'b0;
            n_out_en = 1'b1;
            n_in_x = 0; // TODO: Check correctness
            n_in_y = c_in_y;
            n_out_x = c_out_x + 1; // TODO: Check correctness
            n_out_y = c_out_y;
            n_dout = c_buffer[1];
            n_buffer[2] = c_buffer[1];
            n_buffer[1] = c_buffer[0];
            n_buffer[0] = 0;
        end
        S_WO_H_ENDR2: begin
            n_wo_h_state = S_WO_H_INIT;
            n_busy = 1'b0;
            n_out_en = 1'b1;
            n_in_x = 0; // TODO: Check correctness
            n_in_y = c_in_y + 1;
            n_out_x = 0; // TODO: Check correctness
            n_out_y = c_out_y + 1;
            n_dout = c_buffer[1];
            n_buffer[2] = 0;
            n_buffer[1] = 0;
            n_buffer[0] = c_din;
        end
        S_WO_H_ENDU1: begin
            n_wo_h_state = S_WO_H_ENDU2;
            n_busy = 1'b0;
            n_out_en = 1'b1;
            n_in_x = 0; // TODO: Check correctness
            n_in_y = c_in_y;
            n_out_x = c_out_x + 1; // TODO: Check correctness
            n_out_y = c_out_y;
            n_dout = c_buffer[1];
            n_buffer[2] = c_buffer[1];
            n_buffer[1] = c_buffer[0];
            n_buffer[0] = 0;
        end
        S_WO_H_ENDU2: begin
            n_wo_h_state = S_WO_H_INIT;
            n_busy = 1'b0;
            n_out_en = 1'b1;
            n_in_x = 7'd0;
            n_in_y = 7'd0;
            n_out_x = c_out_x + 1;
            n_out_y = c_out_y;
            n_dout = c_buffer[1];
            n_buffer[2] = 0;
            n_buffer[1] = 0;
            n_buffer[0] = 0;
        end
        default: begin
            n_wo_h_state = S_WO_H_INIT;
            n_busy = 1'b0;
            n_out_en = 1'b0;
            n_in_x = 7'd0;
            n_in_y = 7'd0;
            n_out_x = 7'd0;
            n_out_y = 7'd0;
            n_dout = 7'b0;
            n_buffer[2] = 0;
            n_buffer[1] = 0;
            n_buffer[0] = 0;
        end
        endcase
    end
    S_WO_VERT: begin
        n_state = S_INIT;
        n_wo_h_state = c_wo_h_state;
        n_busy = 1'b1;
        n_out_en = 1'b0;
        n_in_x = 7'd0;
        n_in_y = 7'd0;
        n_out_x = 7'd0;
        n_out_y = 7'd0;
        n_dout = c_dout;
        n_buffer[2] = c_buffer[2];
        n_buffer[1] = c_buffer[1];
        n_buffer[0] = c_buffer[0];
    end
    default: begin
        n_state = S_INIT;
        n_wo_h_state = S_WO_H_INIT;
        n_busy = 1'b1;
        n_out_en = 1'b0;
        n_in_x = 7'd0;
        n_in_y = 7'd0;
        n_out_x = 7'd0;
        n_out_y = 7'd0;
        n_dout = c_dout;
        n_buffer[2] = c_buffer[2];
        n_buffer[1] = c_buffer[1];
        n_buffer[0] = c_buffer[0];
    end
    endcase
end

always@(*)begin //this is to check the finish condition, every cycle the system will check through this and determine when to let finish be HIGH
    n_finish = (c_out_en && (dout_addr == 14'd16383)) ? 1'b1 : 1'b0;
    //n_finish = (((((c_lcu_size+1)*c_lcu_y)+c_in_y)*8'd128) + (((c_lcu_size+1)*c_lcu_x)+c_in_x) == 14'd16383) ? 1'b1 : 1'b0;
end

always@(*)begin //Here are all of the Register which value will only follow the input (it is to save the input value)
    n_in_en = c_in_en;
    n_din = c_din;
    n_ipf_type = c_ipf_type;
    n_ipf_band_pos = c_ipf_band_pos;
    n_ipf_wo_class = c_ipf_wo_class;
    n_offset = c_offset;
    n_lcu_x = c_lcu_x;
    n_lcu_y = c_lcu_y;
    n_lcu_size = c_lcu_size;
    n_max_lcu = c_max_lcu;
    n_band_idx = c_band_idx;
end


//---FF/Sequential Part
always@(posedge clk or posedge reset)
begin
    if(reset) begin
        c_in_en <= 1'b0;
        c_din <= 8'd0;
        c_ipf_type <= 2'd0;
        c_ipf_band_pos <= 5'd0;
        c_ipf_wo_class <= 1'b0;
        c_lcu_x <= 3'd0;
        c_lcu_y <= 3'd0;
        c_lcu_size <= 7'd63;
        c_busy <= 1'b0;
        c_finish <= 1'b0;
        c_out_en <= 1'b0;
        c_dout <= 8'd0;
        c_state <= S_INIT;
        c_wo_h_state <= S_WO_H_INIT;
        c_buffer[2] <= 0;
        c_buffer[1] <= 0;
        c_buffer[0] <= 0;
        c_in_x <= 7'd0;
        c_in_y <= 7'd0;
        c_out_x <= 7'd0;
        c_out_y <= 7'd0;
        c_max_lcu <= 2'd1;
        c_offset <= 16'b0;
        c_band_idx <= 8'd0;
    end
    else begin
        c_in_en <= in_en;
        c_busy <= n_busy;
        c_finish <= n_finish;
        c_out_en <= n_out_en;
        c_dout <= n_dout;
        c_state <= n_state;
        c_wo_h_state <= n_wo_h_state;
        c_buffer[2] <= n_buffer[2];
        c_buffer[1] <= n_buffer[1];
        c_buffer[0] <= n_buffer[0];
        c_in_x <= n_in_x;
        c_in_y <= n_in_y;
        c_out_x <= n_out_x;
        c_out_y <= n_out_y;
        if(in_en) begin
            c_din <= din;
            c_ipf_type <= ipf_type;
            c_ipf_band_pos <= ipf_band_pos;
            c_ipf_wo_class <= ipf_wo_class;
            c_offset <= ipf_offset;
            c_lcu_x <= lcu_x;
            c_lcu_y <= lcu_y;
            if (lcu_size == 2'd0) begin
                c_lcu_size <= 7'd15;
                c_max_lcu <= 3'd7;
            end 
            else if (lcu_size == 2'd1) begin
                c_lcu_size <= 7'd31;
                c_max_lcu <= 3'd3;
            end
            else begin
                c_lcu_size <= 7'd63;
                c_max_lcu <= 3'd1;
            end
            c_band_idx <= (din >> 3); // Right shift 3 bits (divide by 8)
        end
        else begin
            c_din <= n_din;
            c_ipf_type <= n_ipf_type;
            c_ipf_band_pos <= n_ipf_band_pos;
            c_ipf_wo_class <= n_ipf_wo_class;
            c_offset <= n_offset;
            c_lcu_x <= n_lcu_x;
            c_lcu_y <= n_lcu_y;
            c_lcu_size <= n_lcu_size;
            c_max_lcu <= n_max_lcu;
            c_band_idx <= n_band_idx;
        end
    end
end
endmodule

module WOVertCalc (
    clk,
    reset,
    offset0,
    offset1,
    offset2,
    offset3,
    dout,
    finish
);
    input   clk;
    input   reset;
    input   [3:0]   offset0;
    input   [3:0]   offset1;
    input   [3:0]   offset2;
    input   [3:0]   offset3;
    output  [7:0]   dout;
    output  finish;

    //StoreData storeData (.*);
endmodule

/*

module StoreData (
    data,
    data_addr
);
    
endmodule
*/


module DoutAddrCtrl (
    clk,
    reset,
    block_size,
    block_x,
    block_y,
    pixel_x,
    pixel_y,
    dout_addr
);
    input   clk;
    input   reset;
    input   [6:0]   block_size;
    input   [2:0]   block_x;
    input   [2:0]   block_y;
    input   [6:0]   pixel_x;
    input   [6:0]   pixel_y;
    output  [13:0]  dout_addr;

    reg [13:0]  addr;

    assign dout_addr = addr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            addr <= 14'd0;
        end
        else begin
            addr <= (((block_size+1) * block_y) + pixel_y) * 8'd128 +
                ((block_size+1) * block_x) + pixel_x;
        end
    end
endmodule
