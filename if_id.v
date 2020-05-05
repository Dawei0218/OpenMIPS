`include "defines.v"
module if_id(
    input wire clk,
    input wire rst,

    // 指令地址
    input wire[`InstAddrBus] if_pc,
    // 指令
    input wire[`InstBus] if_inst,

    // 对应译码阶段的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus] id_inst  
);

always @ (posedge clk)
begin
    if(rst == `RstEnable)
        begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        end
    else
        begin
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
end

endmodule