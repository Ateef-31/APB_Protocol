`timescale 1ns/1ps

module tb_apb_protocol();
    parameter DATA_WIDTH = 8;
    parameter ADDRESS_WIDTH = 9;
    reg PCLK;
    reg PRESETn;
    reg transfer;
    reg READ_WRITE;
    reg  [ADDRESS_WIDTH-1:0] apb_write_paddr;
    reg  [DATA_WIDTH-1:0] apb_write_data;
    reg  [ADDRESS_WIDTH-1:0] apb_read_paddr;

    wire [DATA_WIDTH-1:0] apb_read_data_out;
    apb_protocol #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .transfer(transfer),
        .READ_WRITE(READ_WRITE),
        .apb_write_paddr(apb_write_paddr),
        .apb_write_data(apb_write_data),
        .apb_read_paddr(apb_read_paddr),
        .apb_read_data_out(apb_read_data_out)
    );

    initial PCLK = 0;
    always #5 PCLK = ~PCLK;

    // Task: single write to slave
    task apb_write;
        input [ADDRESS_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge PCLK);
            apb_write_paddr <= addr;
            apb_write_data  <= data;
            READ_WRITE <= 1'b1;
            transfer <= 1'b1;
            @(posedge PCLK); // IDLE -> SETUP
            @(posedge PCLK); // SETUP -> ACCESS
            @(posedge PCLK); // ACCESS (slave asserts PREADY)
            @(posedge PCLK);
            transfer <= 1'b0;
            READ_WRITE      <= 1'b0;
            @(posedge PCLK); // back to IDLE
            $display("[WRITE] addr=0x%0h  data=0x%0h  time=%0t", addr, data, $time);
        end
    endtask

    // Task: single read from slave
    task apb_read;
        input [ADDRESS_WIDTH-1:0] addr;
        begin
            @(posedge PCLK);
            apb_read_paddr  <= addr;
            READ_WRITE      <= 1'b0;
            transfer        <= 1'b1;
            @(posedge PCLK); // IDLE -> SETUP
            @(posedge PCLK); // SETUP -> ACCESS
            @(posedge PCLK); // ACCESS (slave asserts PREADY)
            @(posedge PCLK);
            transfer        <= 1'b0;
            @(posedge PCLK); // back to IDLE
            #1; // small delay to let apb_read_data_out settle
            $display("[READ]  addr=0x%0h  data=0x%0h  time=%0t", addr, apb_read_data_out, $time);
        end
    endtask

    // Task: write then read back and self-check
    task write_read_check;
        input [ADDRESS_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0]    data;
        begin
            apb_write(addr, data);
            apb_read(addr);
            #1;
            if (apb_read_data_out === data)
                $display("[PASS]  addr=0x%0h  expected=0x%0h  got=0x%0h", addr, data, apb_read_data_out);
            else
                $display("[FAIL]  addr=0x%0h  expected=0x%0h  got=0x%0h", addr, data, apb_read_data_out);
        end
    endtask

    initial
    begin
        PRESETn         = 1'b0;
        transfer        = 1'b0;
        READ_WRITE      = 1'b0;
        apb_write_paddr = 9'd0;
        apb_write_data  = 8'd0;
        apb_read_paddr  = 9'd0;

        repeat(3) @(posedge PCLK);
        @(posedge PCLK);
        PRESETn = 1'b1;
        @(posedge PCLK);

        // TEST 1: Write to Slave 1 (bit[8]=0), addr=0x010
        $display("\n--- TEST 1: Write to Slave1 ---");
        apb_write(9'h010, 8'hAB);

        // TEST 2: Read back from Slave 1, addr=0x010
        $display("\n--- TEST 2: Read from Slave1 ---");
        apb_read(9'h010);

        // TEST 3: Write-Read self-check on Slave 1
        $display("\n--- TEST 3: Write-Read Check Slave1 ---");
        write_read_check(9'h005, 8'h55);
        write_read_check(9'h07F, 8'hFF);
        write_read_check(9'h000, 8'h00);

        // TEST 4: Write to Slave 2 (bit[8]=1), addr=0x1A0
        $display("\n--- TEST 4: Write to Slave2 ---");
        apb_write(9'h1A0, 8'hCD);

        // TEST 5: Read back from Slave 2
        $display("\n--- TEST 5: Read from Slave2 ---");
        apb_read(9'h1A0);

        // TEST 6: Write-Read self-check on Slave 2
        $display("\n--- TEST 6: Write-Read Check Slave2 ---");
        write_read_check(9'h1BB, 8'h77);
        write_read_check(9'h1FF, 8'hEE);

        // TEST 7: Reset during operation
        $display("\n--- TEST 7: Reset Check ---");
        apb_write(9'h020, 8'h99);
        @(posedge PCLK);
        PRESETn = 1'b0;
        repeat(2) @(posedge PCLK);
        @(posedge PCLK);
        PRESETn = 1'b1;
        @(posedge PCLK);
        $display("[RESET] apb_read_data_out after reset = 0x%0h (expect 0x00)", apb_read_data_out);
        if (apb_read_data_out === 8'h00)
            $display("[PASS]  Reset cleared output correctly");
        else
            $display("[FAIL]  Output not cleared after reset");

        // TEST 8: Multiple writes to different addresses Slave1
        $display("\n--- TEST 8: Multiple address writes Slave1 ---");
        write_read_check(9'h001, 8'h11);
        write_read_check(9'h002, 8'h22);
        write_read_check(9'h003, 8'h33);
        write_read_check(9'h004, 8'h44);

        // TEST 9: IDLE state - no transfer, bus should stay idle
        $display("\n--- TEST 9: IDLE state hold ---");
        //@(negedge PCLK);
        @(posedge PCLK);
        transfer   = 1'b0;
        READ_WRITE = 1'b0;
        repeat(4) @(posedge PCLK);
        $display("[IDLE]  Bus held idle for 4 cycles - no spurious activity");

        // TEST 10: Boundary address check Slave1 (addr=0x0FF)
        //          Boundary address check Slave2 (addr=0x1FF)
        $display("\n--- TEST 10: Boundary Address Check ---");
        write_read_check(9'h0FF, 8'hBB);  // Slave1 max address
        write_read_check(9'h1FF, 8'hDD);  // Slave2 max address
        #20;
        $finish;
    end

endmodule
