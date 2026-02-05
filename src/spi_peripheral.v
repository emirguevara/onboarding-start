module spi_peripheral #(parameter W = 8) (
    input wire clk,
    input wire rst_n,
    input wire SCLK,
    input wire nCS,
    input wire COPI,
    output [W-1:0] en_reg_out_7_0,
    output [W-1:0] en_reg_out_15_8,
    output [W-1:0] en_reg_pwm_7_0,
    output [W-1:0] en_reg_pwm_15_8,
    output [W-1:0] pwm_duty_cycle
);

//max address for registers
localparam MAX_ADDRESS = 4;

//transaction parameters
localparam ADDRESS_SIZE = 7;
localparam DATA_SIZE = W;
localparam TRANSACTION_SIZE = 1 + ADDRESS_SIZE + DATA_SIZE;

wire [ADDRESS_SIZE-1:0] address;
wire [DATA_SIZE-1:0] data;
wire rw;

reg [TRANSACTION_SIZE-1:0] stream_in;
reg [$clog2(TRANSACTION_SIZE+1)-1:0] bit_count;
reg transaction_active;

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

reg [W-1:0] registers [0:MAX_ADDRESS];
assign en_reg_out_7_0 = registers[0];
assign en_reg_out_15_8 = registers[1];
assign en_reg_pwm_7_0 = registers[2];
assign en_reg_pwm_15_8 = registers[3];
assign pwm_duty_cycle = registers[4];

//synchronizer
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sclk_sync0 <= 0;
        ncs_sync0 <= 1;
        copi_sync0 <= 0;

        sclk_sync1 <= 0;
        ncs_sync1 <= 1;
        copi_sync1 <= 0;

        sclk_sync2 <= 0;
        ncs_sync2 <= 1;
    end else begin
        sclk_sync0 <= SCLK;
        ncs_sync0 <= nCS;
        copi_sync0 <= COPI;
        
        sclk_sync1 <= sclk_sync0;
        ncs_sync1 <= ncs_sync0;
        copi_sync1 <= copi_sync0;

        sclk_sync2 <= sclk_sync1;
        ncs_sync2 <= ncs_sync1;
    end
end

//edge detection logic
assign ncs_falling = ncs_sync2 & ~ncs_sync1;
assign sclk_rising = ~sclk_sync2 & sclk_sync1;


wire transaction_done = transaction_active && (bit_count == TRANSACTION_SIZE);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stream_in <= 0;
        bit_count <= 0;
        transaction_active <= 0;
    end else begin
        if (ncs_falling) begin
            bit_count <= 0;
            transaction_active <= 1;
        end else if (sclk_rising && transaction_active) begin
            stream_in <= {stream_in[TRANSACTION_SIZE-2:0], copi_sync1};
            bit_count <= bit_count + 1;
        end else if (transaction_done) begin
            transaction_active <= 0;
        end
    end
end

assign {rw, address, data} = stream_in;

//update register values on valid write
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i <= MAX_ADDRESS; i = i + 1)
            registers[i] <= 0;
    end else if (transaction_done && rw && address <= MAX_ADDRESS) begin
        registers[address[$clog2(MAX_ADDRESS+1)-1:0]] <= data;
    end
    
end

endmodule