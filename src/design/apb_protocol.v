module apb_protocol #(DATA_WIDTH = 8 , ADDRESS_WIDTH = 9)
(
    input PCLK,
    input PRESETn,
    input transfer,
    input READ_WRITE,          // 1 = WRITE, 0 = READ
    input [ADDRESS_WIDTH - 1:0] apb_write_paddr,
    input [DATA_WIDTH - 1:0] apb_write_data,
    input [ADDRESS_WIDTH - 1:0] apb_read_paddr,
    output [DATA_WIDTH - 1:0] apb_read_data_out
);

    wire PWRITE;
    wire [ADDRESS_WIDTH - 2:0] PADDR;
    wire [DATA_WIDTH - 1:0] PWDATA;
    wire PSEL1;
    wire PSEL2;
    wire PENABLE;

    wire [DATA_WIDTH - 1:0] PRDATA1;
    wire [DATA_WIDTH - 1:0] PRDATA2;
    wire PREADY1;
    wire PREADY2;

    master #(.DATA_WIDTH(DATA_WIDTH) , .ADDRESS_WIDTH(ADDRESS_WIDTH))
    m1(
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .transfer(transfer),
        .READ_WRITE(READ_WRITE),
        .apb_write_paddr(apb_write_paddr),
        .apb_write_data(apb_write_data),
        .apb_read_paddr(apb_read_paddr),
        .apb_read_data_out(apb_read_data_out),
        .PSEL1(PSEL1),
        .PSEL2(PSEL2),
        .PENABLE(PENABLE),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA1(PRDATA1),  
        .PRDATA2(PRDATA2),
        .PREADY1(PREADY1),
        .PREADY2(PREADY2)
    );

    apb_slave #(.DATA_WIDTH(DATA_WIDTH) , .ADDRESS_WIDTH(ADDRESS_WIDTH))
    slave1(
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL1),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA1),
        .PREADY(PREADY1)
    );

    apb_slave #(.DATA_WIDTH(DATA_WIDTH) , .ADDRESS_WIDTH(ADDRESS_WIDTH))
    slave2(
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL2),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA2),
        .PREADY(PREADY2)
    );

endmodule
