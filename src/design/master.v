module master #(
    parameter DATA_WIDTH = 8, ADDRESS_WIDTH = 9
)
(
    input PCLK,
    input PRESETn,
    input transfer,
    input READ_WRITE,
    input [ADDRESS_WIDTH - 1:0] apb_write_paddr,
    input [DATA_WIDTH - 1:0] apb_write_data,
    input [ADDRESS_WIDTH - 1:0] apb_read_paddr,
    output reg [DATA_WIDTH - 1:0] apb_read_data_out,

    // APB bus outputs to slaves
    output reg PSEL1,
    output reg PSEL2,
    output reg PENABLE,
    output reg [ADDRESS_WIDTH - 2:0] PADDR,   
    output reg PWRITE,
    output reg [DATA_WIDTH - 1:0] PWDATA,

    input [DATA_WIDTH - 1:0] PRDATA1, // inputs to master from slave
    input [DATA_WIDTH - 1:0] PRDATA2,
    input PREADY1,
    input PREADY2
);

    parameter IDLE = 2'b00,
               SETUP = 2'b01,
               ACCESS = 2'b10;

    reg [1:0] state;
    wire PREADY;
    assign PREADY = PSEL1 ? PREADY1 :
                    PSEL2 ? PREADY2 : 1'b0;

    always @(posedge PCLK or negedge PRESETn)
    begin
        if(!PRESETn)
        begin
            state <= IDLE;
            PSEL1 <= 1'b0;
            PSEL2 <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE <= 1'b0;
            PADDR <= {(ADDRESS_WIDTH-1){1'b0}};
            PWDATA <= {DATA_WIDTH{1'b0}};
            apb_read_data_out <= {DATA_WIDTH{1'b0}};
        end
        else
        begin
            case(state)
            IDLE:
                begin
                    PENABLE <= 0;
                    if(transfer)
                    begin
                        if(READ_WRITE)
                        begin
                            PADDR  <= apb_write_paddr[ADDRESS_WIDTH-2:0];
                            PWDATA <= apb_write_data;
                            PWRITE <= 1'b1;
                
                            PSEL1 <= ~apb_write_paddr[ADDRESS_WIDTH-1];
                            PSEL2 <=  apb_write_paddr[ADDRESS_WIDTH-1];
                        end
                        else
                        begin
                            PADDR  <= apb_read_paddr[ADDRESS_WIDTH-2:0];
                            PWRITE <= 1'b0;
                
                            PSEL1 <= ~apb_read_paddr[ADDRESS_WIDTH-1];
                            PSEL2 <=  apb_read_paddr[ADDRESS_WIDTH-1];
                        end
                
                        state <= SETUP;
                    end
                end
            SETUP:
            begin
                PENABLE <= 1'b1;
                state <= ACCESS;
            end
            ACCESS:
            begin
                if(PREADY)
                begin
                    if(!PWRITE)
                    begin
                        if(PSEL1)
                            apb_read_data_out <= PRDATA1;
                        else if (PSEL2)
                            apb_read_data_out <= PRDATA2;
                    end
                    if(!transfer)
                    begin
                        state <= IDLE;
                        PENABLE <= 1'b0;
                        PSEL1 <= 1'b0;
                        PSEL2 <= 1'b0;
                    end
                    else
                    begin
                        state <= SETUP;
                        PENABLE <= 1'b0;  
                        PWRITE <= READ_WRITE;
                        if(READ_WRITE)    // WRITE operation
                        begin
                            PADDR <= apb_write_paddr[ADDRESS_WIDTH-2:0];
                            PWDATA <= apb_write_data;
                            PSEL1 <= (apb_write_paddr[ADDRESS_WIDTH-1] == 1'b0);
                            PSEL2 <= (apb_write_paddr[ADDRESS_WIDTH-1] == 1'b1);
                        end
                        else               // READ operation
                        begin
                            PADDR <= apb_read_paddr[ADDRESS_WIDTH-2:0];
                            PSEL1 <= (apb_read_paddr[ADDRESS_WIDTH-1] == 1'b0);
                            PSEL2 <= (apb_read_paddr[ADDRESS_WIDTH-1] == 1'b1);
                        end
                    end
                end
            end
            default: state <= IDLE;
            endcase
        end
    end
endmodule
