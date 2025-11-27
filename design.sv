//===================
// Design DUT UART_TX
//===================
module uart_tx (
  input        clk,
  input        rst_n,
  input  [7:0] tx_data,
  input        tx_start,
  output reg   tx,
  output reg   busy
);

  typedef enum bit [1:0] {IDLE, START, DATA, STOP} state_e;
  state_e state;
  
  reg [2:0] bit_idx;
  reg [1:0] clk_count;
  reg [7:0] data_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state     <= IDLE;
      tx        <= 1'b1; 
      busy      <= 0;
      bit_idx   <= 0;
      clk_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          tx   <= 1'b1;
          busy <= 0;
          if(tx_start) begin
            state     <= START;
            data_reg  <= tx_data;
            busy      <= 1;
            clk_count <= 0;
          end
        end
        
        START: begin
          tx <= 1'b0;
          
          if(clk_count < 3) begin
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            state     <= DATA;
            bit_idx   <= 0;
          end
        end
        
        DATA: begin
          tx <= data_reg[bit_idx];
          
          if(clk_count < 3) begin 
            clk_count <= clk_count + 1;
          end else begin
            clk_count <= 0;
            if(bit_idx < 7) begin
              bit_idx <= bit_idx + 1; 
            end else begin
              state <= STOP;
            end
          end
        end
        
        STOP: begin
          tx <= 1'b1;
          
          if(clk_count < 3) begin
            clk_count <= clk_count + 1;
          end else begin
            state <= IDLE;
            busy  <= 0;
          end
        end
      endcase
    end  
  end
endmodule

