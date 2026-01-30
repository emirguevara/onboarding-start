module spi_peripheral #(parameter W = 8) (
    input wire clk,
    input wire rst_n,
    input wire SCLK,
    input wire nCS,
    input wire COPI,
    output reg [W-1:0] reg_0x00,
    output reg [W-1:0] reg_0x01,
    output reg [W-1:0] reg_0x02,
    output reg [W-1:0] reg_0x03,
    output reg [W-1:0] reg_0x04 
);

//max address for registers
localparam MAX_ADDRESS = 4;

//transaction parameters
localparam ADDRESS_SIZE = 7;
localparam DATA_SIZE = W;
localparam TRANSACTION_SIZE = 1 + ADDRESS_SIZE + DATA_SIZE;

//spi transaction stages
localparam IDLE        = 2'b00,
           TRANSACTION = 2'b01,
           VALIDATION  = 2'b10,
           UPDATE      = 2'b11;

reg [1:0] state, next;

//input counter used during TRANSACTION state
reg [$clog2(TRANSACTION_SIZE)-1:0] transaction_cntr;

//Adress/data input bits received before validation
reg [TRANSACTION_SIZE-1:0] unvalidated_input;
wire [ADDRESS_SIZE-1:0] address;
wire [DATA_SIZE-1:0] data;
wire rw;

//first stage of the synchronizer
reg sclk_sync0;
reg ncs_sync0;
reg copi_sync0;

//second stage of the synchronizer
reg sclk_sync1;
reg ncs_sync1;
reg copi_sync1;

//third stage used for edge detection
reg sclk_sync2;
reg ncs_sync2;

//wires for edge detection
wire ncs_falling;
wire sclk_rising;
wire ncs_rising;

//synchronizer
always @(posedge clk) begin
    if (!rst_n) begin
        sclk_sync0 <= 0;
        ncs_sync0 <= 1;
        copi_sync0 <= 0;

        sclk_sync1<= 0;
        ncs_sync1<= 1;
        copi_sync1<= 0;

        sclk_sync2<= 0;
        ncs_sync2<= 1;
    end else begin
        sclk_sync0 <= SCLK;
        ncs_sync0 <= nCS;
        copi_sync0 <= COPI;
        
        sclk_sync1 <=  sclk_sync0;
        ncs_sync1 <= ncs_sync0;
        copi_sync1 <= copi_sync0;

        sclk_sync2 <=  sclk_sync1;
        ncs_sync2 <= ncs_sync1;

    end
    
end

//edge detection logic
assign ncs_falling = ncs_sync2 & ~ncs_sync1;  
assign ncs_rising  = ~ncs_sync2 & ncs_sync1;  
assign sclk_rising = ~sclk_sync2 & sclk_sync1;

//state machine to process R/W | address[6:0] | data [7:0]
always @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else        state <= next;
end

always @(*) begin
    next = 2'bx;
    case (state)
        //Transaction starts on nCS falling edge and copi first bit is 1 (write)
        IDLE: if (ncs_falling) next = TRANSACTION;
              else             next = IDLE;
        TRANSACTION: if (transaction_cntr != 0) next = TRANSACTION;
                     else                              next = VALIDATION;
        VALIDATION: if (address > MAX_ADDRESS) next = IDLE;
                    else                       next = UPDATE;
        UPDATE: next = IDLE;
    endcase
end

//count and store input bits received during TRANSACTION state
always @(posedge clk) begin
    if (!rst_n) begin
        transaction_cntr <= TRANSACTION_SIZE-1;
        unvalidated_input <= 0;
    end else begin
        if (state == IDLE) begin
            transaction_cntr <= TRANSACTION_SIZE-1;
            unvalidated_input <= 0;
        end else if (state == TRANSACTION && sclk_rising) begin
            unvalidated_input[transaction_cntr] <= copi_sync1;
            transaction_cntr <= transaction_cntr - 1;
        end
    end       
end
assign {rw, address, data} = unvalidated_input;

//update register values during UPDATE
always @(posedge clk) begin
    if (!rst_n) begin
        reg_0x00 <= 0;
        reg_0x01 <= 0;
        reg_0x02 <= 0;
        reg_0x03 <= 0;
        reg_0x04 <= 0;
    end else begin
        if (state == UPDATE) begin
            case (address)
                0: reg_0x00 <= data;
                1: reg_0x01 <= data;
                2: reg_0x02 <= data;
                3: reg_0x03 <= data;
                4: reg_0x04 <= data;
            endcase
        end
    end
    
end
endmodule