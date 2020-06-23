// flash_reader.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module flash_reader #(
    parameter ASSUME_QPI = 0
) (
    input clk,
    input reset,

    input valid,
    output reg ready,
    input [23:0] address,
    output reg [31:0] data,

    output reg flash_clk_en,
    output reg flash_csn,
    output reg [3:0] flash_in,
    output reg [3:0] flash_in_en,
    input [3:0] flash_out
);
    localparam DUMMY_CYCLES = ASSUME_QPI ? 0 : 4;

    localparam CRM_BYTE = 8'h20;

    reg [4:0] state;

    wire [3:0] byte_state = state[4:1];
    wire nybble_state = state[0];

    reg [7:0] buffer;

    reg [3:0] read_buffer;
    wire [7:0] read_byte = {read_buffer, flash_out};

    always @(posedge clk) begin
        if (nybble_state) begin
            read_buffer <= flash_out;
        end
    end

    reg [7:0] selected_byte;

    always @* begin
        case (byte_state)
            0: selected_byte = address[23:16];
            1: selected_byte = address[15:8];
            2: selected_byte = address[7:0];
            default: selected_byte = CRM_BYTE;
        endcase
    end

    always @(posedge clk) begin
        if (!nybble_state) begin
            case (byte_state - (DUMMY_CYCLES / 2))
                5: data[7:0] <= read_byte;
                6: data[15:8] <= read_byte;
                7: data[23:16] <= read_byte;
                8: data[31:24] <= read_byte;
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset || !valid || ready) begin
            flash_in <= 0;
            flash_in_en <= 0;
        end else begin
            case (byte_state)
                0, 1, 2, 3: flash_in_en <= 4'hf;
                default: flash_in_en <= 0;
            endcase

            flash_in <= nybble_state ? selected_byte[3:0] : selected_byte[7:4];
        end
    end

    always @(posedge clk) begin
        if (reset || !valid || ready) begin
            flash_clk_en <= 0;
            flash_csn <= 1;
            state <= 0;
            ready <= 0;
        end else begin
            flash_csn <= 0;
            state <= state + 1;
            flash_clk_en <= 1;

            if (state == (5'h10 + DUMMY_CYCLES)) begin
                ready <= 1;
            end
        end
    end

endmodule
