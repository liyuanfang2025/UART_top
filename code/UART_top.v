module UART_top #(
    parameter top_size=8
)(
    input     clk,
    input     res,
    input     RX,               //接收的数据
    input     en_TX_out,        //发送数据使能
    input     TX_flag,          //发送数据偶校验结果反馈
    output    TX,               //发送的数据
    output    en_RX_in,         //接收数据使能
    output    RX_flag           //接收数据偶校验结果反馈
);
wire [top_size-1:0] PRO_in;
wire                en_PRO_in;
wire                TX_rdy;
wire                en_TX_in;
wire [top_size-1:0] TX_in;
UART_RX RXer(
    .RX_clk(clk),
    .RX_res(res),
    .RX_in(RX),
    .en_RX_in(en_RX_in),
    .RX_out(PRO_in),
    .en_RX_out(en_PRO_in),
    .RX_flag(RX_flag)
);
UART_PRO PROer(
    .PRO_clk(clk),
    .PRO_res(res),
    .PRO_in(PRO_in),
    .en_PRO_in(en_PRO_in),
    .PRO_rdy(TX_rdy),
    .PRO_out(TX_in),
    .en_PRO_out(en_TX_in)
);
UART_TX TXer(
    .TX_clk(clk),
    .TX_res(res),
    .TX_in(TX_in),
    .en_TX_in(en_TX_in),
    .en_TX_out(en_TX_out),
    .TX_flag(TX_flag),
    .TX_rdy(TX_rdy),
    .TX_out(TX)
);
endmodule
module UART_RX #(
    parameter RX_state_size=2,
              RX_cont_size=11,
              RX_bits_size=4,
              RX_C_BPS115200=868,       //接收器波特率115200
              RX_C_BPS115200_half=434,
              RX_size=9,
              RX_idle=0,
              RX_receive=1,
              RX_send=2
)(
    input                    RX_clk,
    input                    RX_res,
    input                    RX_in,     //接收的数据
    output reg               en_RX_in,  //可以接收数据的信号
    output reg [RX_size-2:0] RX_out,    //发送的并行数据
    output reg               en_RX_out, //可以发送数据的信号
    output reg               RX_flag    //接收数据偶校验的结果
);
reg [RX_state_size-1:0] RX_state;       //状态寄存器
reg [RX_cont_size-1:0]  RX_cont;        //时钟周期计数器
reg [RX_size-1:0]       RX_reg;         //数据接收寄存器
reg [RX_bits_size-1:0]  RX_bits;        //数据位数计数器
always@(posedge RX_clk or negedge RX_res) begin
    if(~RX_res) begin
        en_RX_in<='b1;
        RX_out<='b0;
        en_RX_out<='b0;
        RX_state<=RX_idle;
        RX_cont<='b0;
        RX_bits<='b0;
        RX_reg<='b0;
        RX_flag<='b1;
    end
        else begin
            case(RX_state)
                RX_idle:begin
                    en_RX_out<='b0;
                    if(~RX_in) begin
                        en_RX_in<='b0;
                        if(RX_cont==RX_C_BPS115200_half-1) begin
                            RX_cont<='b0;
                            RX_state<=RX_receive;
                        end
                            else RX_cont<=RX_cont+1'b1;
                    end
                end
                RX_receive:begin
                    if(RX_bits==RX_size) begin
                        RX_cont<='b0;
                        RX_bits<='b0;
                        RX_state<=RX_send;
                    end
                        else if(RX_cont==RX_C_BPS115200-1) begin
                            RX_reg[RX_bits]<=RX_in;
                            RX_bits<=RX_bits+1'b1;
                            RX_cont<='b0;
                        end
                            else RX_cont<=RX_cont+1'b1;
                end
                RX_send:begin
                    if(RX_cont==RX_C_BPS115200-1) begin //偶校验判断接收数据是否正确
                        if(RX_reg[RX_size-1]==(^RX_reg[RX_size-2:0])) begin  
                            RX_flag<='b1;
                            RX_out<=RX_reg[RX_size-2:0];
                            en_RX_out<='b1;  
                            RX_cont<='b0;
                            en_RX_in<='b1;
                            RX_state<=RX_idle;
                         end
                            else begin
                                RX_flag<='b0;
                                RX_cont<='b0;
                                RX_reg<='b0;
                                en_RX_in<='b1;
                                RX_state<=RX_idle;
                            end
                    end
                        else RX_cont<=RX_cont+1'b1;
                end
                default:begin
                    en_RX_in<='b1;
                    RX_out<='b0;
                    en_RX_out<='b0;
                    RX_cont<='b0;
                    RX_bits<='b0;
                    RX_reg<='b0;
                    RX_flag<='b1;
                    RX_state<=RX_idle;
                end
            endcase
        end
end
endmodule
module UART_PRO #(
    parameter PRO_size=8,
              PRO_state_size=2,
              PRO_cont_size=2,
              PRO_receive=0,
              PRO_process=1,
              PRO_send=2,
              PRO_ADD=8'h0a,
              PRO_SUB=8'h0b,
              PRO_AND=8'h0c,
              PRO_OR=8'h0d
)(
    input                     PRO_clk,
    input                     PRO_res,
    input      [PRO_size-1:0] PRO_in,    //接收的并行数据
    input                     en_PRO_in, //接收数据使能
    input                     PRO_rdy,   //发送数据使能
    output reg [PRO_size-1:0] PRO_out,   //发送的并行数据
    output reg                en_PRO_out //发送数据准备完成信号
);
reg [PRO_size-1:0]       A_reg;          //操作数寄存器
reg [PRO_size-1:0]       B_reg;          //操作数寄存器
reg [PRO_size-1:0]       PRO_reg;        //指令寄存器
reg [PRO_state_size-1:0] PRO_state;      //状态寄存器
reg [PRO_cont_size-1:0]  PRO_cont;       //时钟周期计数器
always@(posedge PRO_clk or negedge PRO_res) begin
    if(~PRO_res) begin
        A_reg<='b0;
        B_reg<='b0;
        PRO_reg<='b0;
        PRO_cont<='b0;
        PRO_out<='b0;
        en_PRO_out<='b0;
        PRO_state<=PRO_receive;        
    end
        else begin
            case(PRO_state)
                PRO_receive:begin
                    en_PRO_out<='b0;
                    if(PRO_cont==PRO_cont_size+1) begin
                        PRO_cont<='b0;
                        PRO_state<=PRO_process;
                    end
                        else if(en_PRO_in) begin //依次将接收的数据存入A_reg、B_reg、PRO_reg
                            PRO_reg<=PRO_in;
                            B_reg<=PRO_reg;
                            A_reg<=B_reg;
                            PRO_cont<=PRO_cont+1'b1;
                        end
                end
                PRO_process:begin
                    case(PRO_reg)
                        PRO_ADD: PRO_out<=A_reg+B_reg;
                        PRO_SUB: PRO_out<=A_reg-B_reg;
                        PRO_AND: PRO_out<=A_reg&B_reg;
                        PRO_OR:  PRO_out<=A_reg|B_reg;
                    endcase
                    PRO_state<=PRO_send;
                end
                PRO_send:begin
                    if(PRO_rdy) begin
                        en_PRO_out<='b1;
                        PRO_state<=PRO_receive;  
                    end
                end
                default:begin
                    A_reg<='b0;
                    B_reg<='b0;
                    PRO_reg<='b0;
                    PRO_cont<='b0;
                    PRO_out<='b0;
                    en_PRO_out<='b0;
                    PRO_state<=PRO_receive;
                end
            endcase
        end
end
endmodule
module UART_TX #(
    parameter TXin_size=8,
              TX_state_size=2,
              TXout_size=11,
              TX_cont_size=11,
              TX_bits_size=4,
              TX_C_BPS115200=868,                //发送器波特率为115200
              TX_receive=0,
              TX_send=1,
              TX_judge=2
)(
    input                      TX_clk,
    input                      TX_res,
    input      [TXin_size-1:0] TX_in,            //接收的并行数据
    input                      en_TX_in,         //数据接收使能
    input                      en_TX_out,        //发送数据使能
    input                      TX_flag,          //发送数据偶校验结果反馈
    output reg                 TX_rdy,           //可以接收数据的信号
    output reg                 TX_out            //发送的数据
);
reg        [TX_state_size-1:0] TX_state;         //状态寄存器
reg signed [TXout_size-1:0]    TX_reg;           //数据发送寄存器
reg        [TXout_size-1:0]    TX_reg_buf;       //数据重发寄存器
reg        [TX_cont_size-1:0]  TX_cont;          //时钟周期计数器
reg        [TX_bits_size-1:0]  TX_bits;          //数据位数计数器
always@(posedge TX_clk or negedge TX_res) begin
    if(~TX_res) begin
        TX_rdy<='b1;
        TX_reg<='b0;
        TX_reg_buf<='b0;
        TX_out<='b1;
        TX_cont<='b0;
        TX_bits<='b0;
        TX_state<=TX_receive;
    end
        else begin
            case(TX_state)
                TX_receive:begin
                    if(TX_rdy&en_TX_in) begin
                        TX_reg<={1'b1,(^TX_in),TX_in,1'b0}; //偶校验位(^TX_in)
                        TX_reg_buf<={1'b1,(^TX_in),TX_in,1'b0};
                        TX_rdy<='b0;
                        TX_state<=TX_send;
                    end
                end
                TX_send:begin
                    if(en_TX_out) begin
                        TX_out<=TX_reg[0];
                        if(TX_bits==TXout_size) begin
                            TX_cont<='b0;
                            TX_bits<='b0;
                            TX_state<=TX_judge;
                        end
                            else if(TX_cont==TX_C_BPS115200-1) begin
                                TX_cont<='b0;
                                TX_reg<=TX_reg>>>1;
                                TX_bits<=TX_bits+1'b1;
                            end
                                else TX_cont<=TX_cont+1'b1;
                    end
                end
                TX_judge:begin //判断发送数据偶校验结果是否正确
                    if(TX_flag) begin
                        TX_reg<='b0;
                        TX_rdy<='b1;
                        TX_state<=TX_receive;
                    end
                        else begin //发送数据偶校验结果错误，重新发送
                            TX_reg<=TX_reg_buf;
                            TX_state<=TX_send; 
                        end
                end
                default:begin
                    TX_rdy<='b1;
                    TX_reg<='b0;
                    TX_reg_buf<='b0;
                    TX_out<='b1;
                    TX_cont<='b0;
                    TX_bits<='b0;
                    TX_state<=TX_receive; 
                end
            endcase
        end
end
endmodule