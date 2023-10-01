module RS232_Receiver (
reset_neg,
clock,
rx_receiver,
rx_dataout_ready,
rx_dataout,
// optional pins for identifying long break in data reception
rx_endofpacket,
rx_Idle,
Exe_LogicImp
);
parameter HIGH = 1'b1;
parameter LOW = 1'b0;
//`ifdef ML401
parameter CLOCK_FREQ = 100000000; // 100MHz
//`else // ifdef ML461
// parameter CLOCK_FREQ = 33000000; // 33MHz
//`endif
//parameter BAUD_RATE = 9600; // 115200;
parameter BAUD_RATE = 115200; // 115200;
// BAUD_RATE generator (Uses 8 times oversampling)
parameter BAUD_RATE_8X = BAUD_RATE*8;

parameter BAUD_8X_ACC_WIDTH = 16;
input reset_neg;
input clock;
input rx_receiver;
input Exe_LogicImp;
output rx_dataout_ready;
output [7:0] rx_dataout;
// optional pins for identifying long break in data reception
// We also detect if a gap occurs in the received stream of characters
// That can be useful if multiple characters are sent in burst
// so that multiple characters can be treated as a "packet"
output rx_endofpacket; // one clock pulse, when no more data
// is received (rx_Idle is going high)
output rx_Idle; // no data is being received
wire [BAUD_8X_ACC_WIDTH:0] Baud_8X_Incr;
reg [BAUD_8X_ACC_WIDTH:0] Baud_8X_Acc;
assign Baud_8X_Incr = ((BAUD_RATE_8X << (BAUD_8X_ACC_WIDTH - 7)) +
(CLOCK_FREQ >> 8))
/ (CLOCK_FREQ >> 7);
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
Baud_8X_Acc <= {(BAUD_8X_ACC_WIDTH + 1){LOW}};
end
else if (Exe_LogicImp == 1'b1) Baud_8X_Acc <= {(BAUD_8X_ACC_WIDTH +
1){LOW}};
else
begin
Baud_8X_Acc <= Baud_8X_Acc[BAUD_8X_ACC_WIDTH - 1:0]
+ Baud_8X_Incr;
end
end
wire Baud_Pulse_8x = Baud_8X_Acc[BAUD_8X_ACC_WIDTH];
////////////////////////////
reg [1:0] Rx_Sync;
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
Rx_Sync <= 2'b11;
end
else if (Exe_LogicImp == 1'b1) Rx_Sync <= 2'b11;
else if (Baud_Pulse_8x)
begin
Rx_Sync <= {Rx_Sync[0], rx_receiver};
end
end
reg [1:0] Rx_Count;

reg Rx_Bit;
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
Rx_Count <= 2'b11;
Rx_Bit <= HIGH;
end
else if (Exe_LogicImp == 1'b1)
begin
Rx_Count <= 2'b11;
Rx_Bit <= HIGH;
end
else if(Baud_Pulse_8x)
begin
if( Rx_Sync[1] && Rx_Count!=2'b11) Rx_Count <= Rx_Count + 2'h1;
else
if(~Rx_Sync[1] && Rx_Count!=2'b00) Rx_Count <= Rx_Count - 2'h1;
if(Rx_Count==2'b00) Rx_Bit <= 1'b0;
else
if(Rx_Count==2'b11) Rx_Bit <= 1'b1;
end
end
reg [3:0] State;
reg [3:0] Bit_Spacing;
// "next_bit" controls when the data sampling occurs
// depending on how noisy the rx_receiver is, different values might work
better
// with a clean connection, values from 8 to 11 work
wire next_bit = (Bit_Spacing==4'd10);
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
Bit_Spacing <= 4'b0000;
end
else if (Exe_LogicImp == 1'b1) Bit_Spacing <= 4'b0000;
else if(State==0)
begin
Bit_Spacing <= 4'b0000;
end
else if(Baud_Pulse_8x)
begin
Bit_Spacing <= {Bit_Spacing[2:0] + 4'b0001} | {Bit_Spacing[3], 3'b000};
end
end
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
State <= 4'b0000;

end
else if (Exe_LogicImp == 1'b1) State <= 4'b0000;
else if(Baud_Pulse_8x)
begin
case(State)
4'b0000: if(~Rx_Bit) State <= 4'b1000; // start bit found?
4'b1000: if(next_bit) State <= 4'b1001; // bit 0
4'b1001: if(next_bit) State <= 4'b1010; // bit 1
4'b1010: if(next_bit) State <= 4'b1011; // bit 2
4'b1011: if(next_bit) State <= 4'b1100; // bit 3
4'b1100: if(next_bit) State <= 4'b1101; // bit 4
4'b1101: if(next_bit) State <= 4'b1110; // bit 5
4'b1110: if(next_bit) State <= 4'b1111; // bit 6
4'b1111: if(next_bit) State <= 4'b0001; // bit 7
4'b0001: if(next_bit) State <= 4'b0000; // stop bit
default: State <= 4'b0000;
endcase
end
end
reg [7:0] rx_dataout;
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
rx_dataout <= 8'h00;
end
else if (Exe_LogicImp == 1'b1) rx_dataout <= 8'h00;
else if(Baud_Pulse_8x && next_bit && State[3])
begin
rx_dataout <= {Rx_Bit, rx_dataout[7:1]};
end
end
reg rx_dataout_ready, RxD_data_error;
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
rx_dataout_ready <= LOW;
RxD_data_error <= LOW;
end
else if (Exe_LogicImp == 1'b1)
begin
rx_dataout_ready <= LOW;
RxD_data_error <= LOW;
end
else
begin
rx_dataout_ready <= (Baud_Pulse_8x && next_bit && State==4'b0001 &&
Rx_Bit); // ready only if the stop bit is received
RxD_data_error <= (Baud_Pulse_8x && next_bit && State==4'b0001 &&
~Rx_Bit); // error if the stop bit is not received
end
end

// Optional functionality for detection of gap if it occurs in the
// received stream of characters.
reg [4:0] gap_count;
always @ (posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
gap_count<=5'h00;
end
else if (Exe_LogicImp == 1'b1) gap_count<=5'h00;
else if (State!=0)
begin
gap_count<=5'h00;
end
else if (Baud_Pulse_8x & ~gap_count[4])
begin
gap_count <= gap_count + 5'h01;
end
end
assign rx_Idle = gap_count[4];
reg rx_endofpacket;
always @(posedge clock or negedge reset_neg)
begin
if (reset_neg == LOW)
begin
rx_endofpacket <= LOW;
end
else if (Exe_LogicImp == 1'b1) rx_endofpacket <= LOW;
else
begin
rx_endofpacket <= Baud_Pulse_8x & (gap_count==5'h0F);
end
end
endmodule
