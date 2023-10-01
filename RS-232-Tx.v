module RS232_Transmitter (
clock,
reset_neg,
tx_datain_ready,
Present_Processing_Completed,
tx_datain,
tx_transmitter,
tx_transmitter_valid
);
parameter HIGH = 1'b1;
parameter LOW = 1'b0;
parameter CLOCK_FREQ = 100000000; // 100MHz
// parameter CLOCK_FREQ = 33000000; // 33MHz
parameter BAUD_RATE = 115200; // ;9600
parameter REG_INPUT = 1; // in REG_INPUT mode, the input doesn't have to
stay valid while the character is been transmitted
parameter BAUD_ACC_WIDTH = 16;
input reset_neg;
input clock;
input tx_datain_ready;
input Present_Processing_Completed;
input [7:0] tx_datain;
output tx_transmitter;
output tx_transmitter_valid;
reg tx_transmitter;
// Baud generator
wire [BAUD_ACC_WIDTH:0] Baun_Inc;
reg [BAUD_ACC_WIDTH:0] Baud_Acc;
assign Baun_Inc = ((BAUD_RATE << (BAUD_ACC_WIDTH - 4)) + (CLOCK_FREQ >> 5))
/ (CLOCK_FREQ >> 4);
wire Baud_Pulse = Baud_Acc[BAUD_ACC_WIDTH];
always @ (posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
Baud_Acc <= {(BAUD_ACC_WIDTH + 1){LOW}};
end
else if (Present_Processing_Completed == 1'b1) Baud_Acc <=
{(BAUD_ACC_WIDTH + 1){LOW}};
else if (tx_transmitter_valid)
begin
Baud_Acc <= Baud_Acc[BAUD_ACC_WIDTH - 1:0] + Baun_Inc;
end
end

// Transmitter State machine
reg [3:0] State;
wire tx_Xfer_Ready = (State==0);
assign tx_transmitter_valid = ~tx_Xfer_Ready;
reg [7:0] tx_data_reg;
always @ (posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
tx_data_reg <= 8'hff;
end
else if (Present_Processing_Completed == 1'b1) tx_data_reg <= 8'hff;
else if (tx_Xfer_Ready & tx_datain_ready)
begin
tx_data_reg <= tx_datain;
end
end
wire [7:0] Tx_Data_Byte;
assign Tx_Data_Byte = REG_INPUT ? tx_data_reg : tx_datain;
always @ (posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
State <= 4'b0000;
end
else if (Present_Processing_Completed == 1'b1) State <= 4'b0000;
else
begin
case(State)
4'b0000: if(tx_datain_ready) State <= 4'b0100;
// 4'b0001: if(Baud_Pulse) State <= 4'b0100; // registered input
4'b0100: if(Baud_Pulse) State <= 4'b1000; // start
4'b1000: if(Baud_Pulse) State <= 4'b1001; // bit 0
4'b1001: if(Baud_Pulse) State <= 4'b1010; // bit 1
4'b1010: if(Baud_Pulse) State <= 4'b1011; // bit 2
4'b1011: if(Baud_Pulse) State <= 4'b1100; // bit 3
4'b1100: if(Baud_Pulse) State <= 4'b1101; // bit 4
4'b1101: if(Baud_Pulse) State <= 4'b1110; // bit 5
4'b1110: if(Baud_Pulse) State <= 4'b1111; // bit 6
4'b1111: if(Baud_Pulse) State <= 4'b0010; // bit 7
4'b0010: if(Baud_Pulse) State <= 4'b0000; // stop1
// 4'b0011: if(Baud_Pulse) State <= 4'b0000; // stop2
default: if(Baud_Pulse) State <= 4'b0000;
endcase
end
end
// Output mux
reg MuxBit;
always @ (State or Tx_Data_Byte)
begin
case (State[2:0])

3'd0: MuxBit <= Tx_Data_Byte[0];
3'd1: MuxBit <= Tx_Data_Byte[1];
3'd2: MuxBit <= Tx_Data_Byte[2];
3'd3: MuxBit <= Tx_Data_Byte[3];
3'd4: MuxBit <= Tx_Data_Byte[4];
3'd5: MuxBit <= Tx_Data_Byte[5];
3'd6: MuxBit <= Tx_Data_Byte[6];
3'd7: MuxBit <= Tx_Data_Byte[7];
endcase
end
// Put together the start, data and stop bits
always @ (posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
tx_transmitter <= HIGH;
end
else if (Present_Processing_Completed == 1'b1) tx_transmitter <= HIGH;
else
begin
tx_transmitter <= (State < 4) | (State[3] & MuxBit); // register the
output to make it glitch free
end
end
endmodule
