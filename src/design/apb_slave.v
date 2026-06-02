module apb_slave #(parameter DATA_WIDTH = 8, ADDRESS_WIDTH = 9)
(
    input PCLK,
    input PRESETn,
    input PSEL,
    input PENABLE,
    input PWRITE,
    input [ADDRESS_WIDTH - 2:0] PADDR,
    input [DATA_WIDTH - 1:0] PWDATA,
    output reg [DATA_WIDTH - 1:0] PRDATA,
    output reg PREADY
);
    reg [DATA_WIDTH - 1:0] mem [0:255];
    integer i;
    always @(posedge PCLK or negedge PRESETn)
    begin
        if(!PRESETn)
        begin
            PREADY <= 1'b0;
            PRDATA <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < 256; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end
        else
        begin
            PREADY <= 1'b0;
            if(PSEL && PENABLE)
            begin
                PREADY <= 1'b1;
                if(PWRITE)
                    mem[PADDR] <= PWDATA;
                else
                    PRDATA <= mem[PADDR];
            end
        end
    end
endmodule
