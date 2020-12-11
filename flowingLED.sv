// 数电流水灯作业
//  将数字逻辑中数据选择器、译码器、计数器、分频器、移 位寄存器等相关知识结合起来，实现一个功能较简单、又 有一定趣味性的项目。培养学生的实践动手能力。
//  能够掌握数字系统层次化设计方法；
//  能够使用Verilog HDL、EDA软件工具进行电路的辅助分析 和设计，并使用FPGA器件进行实现和验证。
//  实现方法具有多样性，实验内容能够逐层次递进。
//  通过课堂实验和课外开放实验相结合的方式，训练学生动 手能力，激发学生创新意识。


//3-8译码器
module decoder3_8(
    input [2:0] data_in,          //3 位信号输入
    input enable,                 //使能信号输入
    output reg [7:0] data_out     //8 位译码信号输出
);
    always @(*) 
    begin
        if (enable) 
        begin
            case (data_in[2:0])    
                //enable=1时,使能信号有效,对 in_data 进行译码，输出 out_data
                3'b000: data_out = 8'b0000_0001;
                3'b001: data_out = 8'b0000_0010;
                3'b010: data_out = 8'b0000_0100;
                3'b011: data_out = 8'b0000_1000;
                3'b100: data_out = 8'b0001_0000;
                3'b101: data_out = 8'b0010_0000;
                3'b110: data_out = 8'b0100_0000;
                3'b111: data_out = 8'b1000_0000;
                default:data_out = 8'b0000_0000;
            endcase
        end
        else 
        begin  
            //enable=0时，输出全无效 
            data_out = 8'b0000_0000;
        end
    end
endmodule


// 4-16 译码器
module decoder4_16(
    input [3:0] data_in,              //4 位信号输入
    input enable,                     //使能信号输入
    output wire [15:0] data_out       //16 位译码信号输出
);
    wire enable_L;  //给到低位3-8译码器的使能信号
    wire enable_H;  //给到高位3-8译码器的使能信号

    //最高位地址位 与上 使能控制位 来选择要工作的3-8译码器
    assign enable_L = enable && (~data_in[3]);  
    assign enable_H = enable && ( data_in[3]);

    decoder3_8 decoder3_8_L(data_in[2:0],enable_L,data_out[7:0]); //控制低八位的译码器
    decoder3_8 decoder3_8_H(data_in[2:0],enable_H,data_out[15:8]);  //控制高八位的译码器

endmodule


//分频器
module prescaler(
    input clk_in,                   //输入 50MHz 时钟
    input rst_n,                    //输入低电平复位信号
    output reg clk_out                  //输出时钟信号
);  
    //注：跑仿真时把它改到了us级，不然太卡了
    reg [24:0] cnt_50M ;  //寄存器变量  存储25位的时钟值

    //把50MHz的时钟分频到1Hz
    always @( posedge clk_in or negedge rst_n ) begin
        //50MHz时钟上升沿或复位下降沿 触发
        if (!rst_n) begin     //复位信号触发：
        cnt_50M <= 25'd0;   //50MHz计数器清零，
        clk_out <= 1'b0;      //1Hz时钟清零。
        end
        else if 
        (cnt_50M == 25'd24/*25'd24_999_999*/) begin  //计数到半周期：
        cnt_50M <= 25'd0;                            //50MHz计数器清零，
        clk_out <= ~clk_out;                         //1Hz时钟跳变。                    
        end
        else cnt_50M <= cnt_50M + 1'd1;  
        //正常情况：50MHz计数器在时钟上升沿计数值+1，1Hz时钟保持。
    end
endmodule


//4位二进制 双向 计数器
module counter16(   
    input clk_in,                   //输入 1Hz 时钟
    input rst_n,                    //输入低电平复位信号
    input cnt_stop,                 //输入计数器停止信号
    input cnt_dir,                  //计数方向
    output reg [ 3: 0 ] cnt_led     //输出 4 位计数器输出
);
 
    always @( posedge clk_in or negedge rst_n ) begin  //1Hz时钟上升沿或复位下降沿触发
        if (!rst_n) cnt_led <= 4'b0000;                         //复位触发：灯信号清零
        else if (cnt_stop) cnt_led <= cnt_led;                  //停止信号触发：灯信号保持
        else cnt_led <= cnt_led + (1'd1)*(cnt_dir?(1):(-1));    //正常情况：计数+1或者-1
    end
endmodule


//计数器实现流水灯
module flowingLED_counter(
    input clk_50MHz,                 //输入50MHz时钟
    input rst_n,                     //输入低电平复位信号
    input flowingLED_stop,           //输入流水灯暂停信号
    output wire [15:0] flowingLED    //输出16线灯通道信号
);
    wire [3:0] cnt_led;  //灯地址值
    reg enable = 1'b1;//使能信号
    reg clk_1Hz;//1Hz时钟信号
    reg cnt_dir = 1'b0 ; //计数方向：0 向下； 1 向上
    
    always @(posedge flowingLED[15])  //在第15个灯的上升沿 触发变向
        cnt_dir <= 1'b0;              //计数变向

    always @(posedge flowingLED[0])   //在第0个灯的上升沿 触发变向
        cnt_dir <= 1'b1;              //计数变向

    prescaler prescaler(clk_50MHz,rst_n,clk_1Hz);          //时钟分频

    counter16 counter_4bit(clk_1Hz,rst_n,flowingLED_stop,cnt_dir,cnt_led);
    
    decoder4_16 decoder4_16(cnt_led,enable,flowingLED);
endmodule


//8位 双向移位 寄存器
module shifting_register_8bit(
    input clk_in,                   //输入 1Hz 时钟
    input enable,                   //使能信号
    input rst_n,                    //输入低电平复位信号
    input mov_stop,                 //停止信号
    input mov_dir,                  //移位方向 0: 左移(L->H)； 1: 右移(H-L)
    input data_in,                  //串行输入
    output reg [7:0] data_out       //8位移位输出
);
    always @ (posedge clk_in ,negedge rst_n) begin
        if(enable) begin
            if(!rst_n) data_out = 8'b0000_0000; //复位清零
            else if(mov_stop) data_out <= data_out; //暂停 输出保持
            else data_out = mov_dir? {data_in,data_out[7:1]} : {data_out[6:0],data_in}; //正常情况：移位 
        end
    end
endmodule

module testbench_shifting_register_8bit;
    reg clock_50MHz = 1'b0;  //时钟信号
    reg reset_n = 1'b1;      //复位信号
    reg stop = 1'b0;         //停止信号
    reg dir = 1'b0;       //选择信号
    wire [7:0] LED_out;     //输出的LED通道
     
    reg [7:0] data_8bit_in = 8'h01; 
    wire data_in;                          //连到8位移位寄存器输入端的线网
    reg [2:0] ptr_in = 3'b000;             //指示data_in连到8位输入数据的哪一位的指针
    reg idle_in = 1'b0;                    //类似于C语言里的NULL大概

    always #1 clock_50MHz = ~clock_50MHz;  //时钟翻转
    initial begin//复位 上电初始化
        #1 reset_n = ~reset_n;
        #1 reset_n = ~reset_n;
    end

    //移位方向改变
    always @(posedge LED_out[0])  dir <= 1'b0; //在第15个灯的上升沿 触发变向                 
    always @(posedge LED_out[7])  dir <= 1'b1; //在第0个灯的上升沿 触发变向

    //串行输入模拟 置数一次 双向流水
    assign data_in = (ptr_in == 3'b111)?idle_in:data_8bit_in[ptr_in];
    always @(posedge clock_50MHz,negedge reset_n) begin
        if(!reset_n) ptr_in =3'b000; 
        else if(ptr_in == 3'b111) ptr_in <= ptr_in;
        else ptr_in <= ptr_in + 1'b1;
    end

    shifting_register_8bit shifting_register_8bit(clock_50MHz,1'b1,reset_n,stop,dir,data_in,LED_out);
endmodule

//16位 双向移位 寄存器
module shifting_register_16bit(
    input clk_in,                   //输入 1Hz 时钟
    input enable,                   //使能信号
    input rst_n,                    //输入低电平复位信号
    input mov_stop,                 //停止信号
    input mov_dir,                  //移位方向 0: 左移(L->H)； 1: 右移(H-L)
    input data_in,                  //串行输入
    output reg [15:0]  data_out     //并行输出
);
    wire data_in_L,data_in_H;  //在双向移位时会改动线网的连接

    assign data_in_H = mov_dir? data_in:data_out[7]  ;
    assign data_in_L = mov_dir? data_out[8]: data_in ;

    shifting_register_8bit shiftReg_L(clk_in,enable,rst_n,mov_stop,mov_dir,data_in_L,data_out[7:0]);   //低移位寄存器
    shifting_register_8bit shiftReg_H(clk_in,enable,rst_n,mov_stop,mov_dir,data_in_H,data_out[15:8]);  //高移位寄存器

    always @( posedge clk_in, negedge rst_n ) begin        //在1Hz时钟上升沿或复位下降沿触发
        if(enable) begin
            if (!rst_n) data_out <= 16'h0000;                         //输出数据 复位
            else if ( mov_stop ) data_out <= data_out;                //输出数据保持不变
        end
    end
endmodule

//移位寄存器实现流水灯
module flowingLED_shift_reg( 
    input clk_50MHz,                  //输入 50MHz 系统时钟
    input rst_n,                      //输入低电平复位信号
    input flowingLED_stop,            //输入流水灯暂停信号
    output reg [15:0] flowingLED      //16位流水灯输出信号
);                               
    reg clk_1Hz;            //1Hz时钟信号
    reg enable = 1'b1;      //使能信号
    reg mov_dir = 1'b0 ;    //移位方向：0 向左； 1 向右

    reg [15:0]data_16bit_in = 16'h0007;    //---------------控制流水灯的那一串数----------------//
    wire data_in;                          //连到16位移位寄存器输入端的线网
    reg [3:0] ptr_in = 4'b0000;                  //指示data_in连到16位输入数据的哪一位的指针
    reg idle_in = 1'b0;                    //类似于C语言里的NULL大概
    
    prescaler prescaler(clk_50MHz,rst_n,clk_1Hz);          //时钟分频

    //移位方向改变
    always @(posedge flowingLED[0])   mov_dir <= 1'b0; //在第0个灯的上升沿 触发变向                 
    always @(posedge flowingLED[15])  mov_dir <= 1'b1; //在第15个灯的上升沿 触发变向

    //串行输入模拟 置数一次 双向流水
    assign data_in = (ptr_in == 4'b1111)?idle_in:data_16bit_in[ptr_in];
    always @(posedge clk_1Hz,negedge rst_n) begin
        if(!rst_n) ptr_in =4'b0000; 
        else if(ptr_in == 4'b1111) ptr_in <= ptr_in;
        else ptr_in <= ptr_in + 1'b1;
    end

    shifting_register_16bit shifting_register_16bit(clk_1Hz,enable,rst_n,flowingLED_stop,mov_dir,data_in,flowingLED);

endmodule


//组合流水灯 （计数器版+移位寄存器版）
module flowingLED_comb(
    input clk_50MHz,                  //输入 50MHz 系统时钟
    input rst_n,                      //输入低电平复位信号
    input flowingLED_stop,            //输入流水灯暂停信号
    input sw_change,                  //选择信号
    output wire [15:0] flowingLED_out  //16 位流水灯输出信号
);
    wire [15:0] flowingLED_cnt_out;         //计数器输出
    wire [15:0] flowingLED_shift_reg_out;   //移位寄存器输出

    assign flowingLED_out = (sw_change ? flowingLED_cnt_out : flowingLED_shift_reg_out);  
    //选择输出16线所接入的通道：
    //sw_change=1 时，计数器输出；
    //sw_change=0 时，移位寄存器输出。

    flowingLED_counter   flowingLED_counter_inst(clk_50MHz,rst_n,flowingLED_stop,flowingLED_cnt_out);//计数器实现流水灯
    flowingLED_shift_reg flowingLED_shift_reg_inst(clk_50MHz,rst_n,flowingLED_stop,flowingLED_shift_reg_out);//移位寄存器实现流水灯
endmodule


`timescale 1ps/1ps
module test_bench_flowingLED_comb;
    reg clock_50MHz = 1'b0;  //时钟信号
    reg reset_n = 1'b1;      //复位信号
    reg stop = 1'b0;         //停止信号
    reg select = 1'b0;       //选择信号
    wire [15:0] LED_out;     //输出的LED通道

    always #1 clock_50MHz = ~clock_50MHz;  //时钟翻转
    
    initial begin//复位 上电初始化
        #1 reset_n = ~reset_n;
        #1 reset_n = ~reset_n;
    end
    
    always /*@(stop == 0)*/ begin//换通道（计数器/移位寄存器）
        #10000 select = ~select;
        #1  reset_n = ~reset_n;
        #1  reset_n = ~reset_n;
    end
    
    flowingLED_comb flowingLED_comb_inst(clock_50MHz,reset_n,stop,select,LED_out);
endmodule