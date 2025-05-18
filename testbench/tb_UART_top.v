`timescale 1ns/1ps
module tb_UART_top #(
    parameter half_cycle_100MHz=5,
              top_state_size=2,
              top_cont_size=11,
              top_bits_size=8,
              top_RX_size=33,
              top_C_BPS115200=868,
              top_ADD=0,
              top_SUB=1,
              top_AND=2,
              top_OR=3
);
reg  clk;
reg  res;
wire RX;
reg  en_TX_out;
reg  TX_flag;
wire TX;
wire en_RX_in;
wire RX_flag;
UART_top UART_top(
    clk,
    res,
    RX,
    en_TX_out,
    TX_flag,
    TX,
    en_RX_in,
    RX_flag
);
initial begin
    res<='b0;
    en_TX_out<='b0;
    TX_flag<='b0;
    #13
    res<='b1;
    en_TX_out<='b1;
    TX_flag<='b1;
    #1500000
    $stop;
end
initial    clk<='b0;
always     #half_cycle_100MHz clk<=~clk;   //时钟频率100MHz
reg        [top_state_size-1:0] top_state; //状态寄存器
reg        [top_cont_size-1:0]  top_cont;  //时钟周期计数器
reg        [top_bits_size-1:0]  top_bits;  //数据位数计数器
reg signed [top_RX_size-1:0]    top_RX;    //发送的数据寄存器
assign     RX=top_RX[0];
always@(posedge clk or negedge res) begin
    if(~res) begin
        top_state<=top_ADD;
        top_cont<='b0;
        top_bits<='b0;
        top_RX<={1'b1,1'b0,8'h0a,1'b0,1'b1,1'b1,8'h0e,1'b0,1'b1,1'b0,8'h0f,1'b0};
    end
        else begin
            case(top_state)
                top_ADD:begin
                    if(top_bits==top_RX_size) begin
                        top_cont<='b0;
                        top_bits<='b0;
                        top_state<=top_SUB;
                        top_RX<={1'b1,1'b1,8'h0b,1'b0,1'b1,1'b1,8'h0e,1'b0,1'b1,1'b0,8'h0f,1'b0};
                    end
                        else begin
                            if(top_cont==top_C_BPS115200-1) begin
                                top_cont<='b0;
                                top_RX<=top_RX>>>1;
                                top_bits<=top_bits+1'b1;
                            end
                                else top_cont<=top_cont+1'b1;
                        end
                end
                top_SUB:begin
                    if(top_bits==top_RX_size) begin
                        top_cont<='b0;
                        top_bits<='b0;
                        top_state<=top_AND;
                        top_RX<={1'b1,1'b0,8'h0c,1'b0,1'b1,1'b1,8'h0e,1'b0,1'b1,1'b0,8'h0f,1'b0};
                    end
                        else begin
                            if(top_cont==top_C_BPS115200-1) begin
                                top_cont<='b0;
                                top_RX<=top_RX>>>1;
                                top_bits<=top_bits+1'b1;
                            end
                                else top_cont<=top_cont+1'b1;
                        end
                end
                top_AND:begin
                    if(top_bits==top_RX_size) begin
                        top_cont<='b0;
                        top_bits<='b0;
                        top_state<=top_OR;
                        top_RX<={1'b1,1'b1,8'h0d,1'b0,1'b1,1'b1,8'h0e,1'b0,1'b1,1'b0,8'h0f,1'b0};
                    end
                        else begin
                            if(top_cont==top_C_BPS115200-1) begin
                                top_cont<='b0;
                                top_RX<=top_RX>>>1;
                                top_bits<=top_bits+1'b1;
                            end
                                else top_cont<=top_cont+1'b1;
                        end
            end
                top_OR:begin
                    if(top_bits==top_RX_size) begin
                        top_cont<='b0;
                        top_bits<='b0;
                        top_state<=top_ADD;
                        top_RX<={1'b1,1'b0,8'h0a,1'b0,1'b1,1'b1,8'h0e,1'b0,1'b1,1'b0,8'h0f,1'b0};
                    end
                        else begin
                            if(top_cont==top_C_BPS115200-1) begin
                                top_cont<='b0;
                                top_RX<=top_RX>>>1;
                                top_bits<=top_bits+1'b1;
                            end
                            else top_cont<=top_cont+1'b1;
                        end
                end
            endcase   
        end
end
endmodule