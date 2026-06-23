`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 10:04:38 AM
// Design Name: 
// Module Name: project_b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module project_b(

    );
endmodule




// ==========================================================
// 1. TOP MODULE: 2세트 통합 제어 및 시각화
// ==========================================================
// ==========================================================
// 1. TOP MODULE: 2세트 통합 제어 및 시각화 (최종 수정본)
// ==========================================================
module fan_dual_system_top(
    input clk, reset_p,
    // 세트 1 (JB1, JB2)
    inout dht11_data_1, output fan_pwm_1,
    // 세트 2 (JB3, JB4)
    inout dht11_data_2, output fan_pwm_2,
    // 제어 입력 (BTNC, BTNU, BTNL, SW1)
    input btn_mode, btn_manual_1, btn_manual_2,
    input sw_select,
    // VGA 출력 (R, G, B 각 4비트)
    output hsync, vsync,
    output [3:0] vga_r, vga_g, vga_b,
    // 표시 장치 (FND, LED)
    output [7:0] seg, [3:0] an,
    output led_mode, led_sw_state
);

    // 내부 데이터 와이어
    wire [7:0] temp1, humi1, temp2, humi2;
    reg [7:0] disp_temp, disp_humi;
    wire fan1_on, fan2_on;
    reg mode_reg, man1_reg, man2_reg;
    
    // 버튼 입력 처리 (Edge Detection)
    wire b_mode, b_man1, b_man2;
    edge_detector_p ed0(.clk(clk), .reset_p(reset_p), .cp(btn_mode), .p_edge(b_mode));
    edge_detector_p ed1(.clk(clk), .reset_p(reset_p), .cp(btn_manual_1), .p_edge(b_man1));
    edge_detector_p ed2(.clk(clk), .reset_p(reset_p), .cp(btn_manual_2), .p_edge(b_man2));

    // [제어 로직] 자동/수동 모드 및 개별 토글
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin 
            mode_reg <= 0; man1_reg <= 0; man2_reg <= 0; 
        end else begin
            if(b_mode) mode_reg <= ~mode_reg;
            if(mode_reg) begin
                if(b_man1) man1_reg <= ~man1_reg;
                if(b_man2) man2_reg <= ~man2_reg;
            end else begin 
                man1_reg <= 0; man2_reg <= 0; 
            end
        end
    end
    assign led_mode = mode_reg;

    // [하드웨어 연결] 센서 및 모터 제어
    dht11_cntr dht1 (.clk(clk), .reset_p(reset_p), .dht11_data(dht11_data_1), .temperature(temp1), .humidity(humi1));
    dht11_cntr dht2 (.clk(clk), .reset_p(reset_p), .dht11_data(dht11_data_2), .temperature(temp2), .humidity(humi2));
    
    assign fan1_on = mode_reg ? man1_reg : (temp1 >= 28 || humi1 >= 70);
    assign fan2_on = mode_reg ? man2_reg : (temp2 >= 28 || humi2 >= 70);
    
    pwm_Nfreq_Nstep pwm1 (.clk(clk), .reset_p(reset_p), .duty(fan1_on ? 8'd200 : 0), .pwm(fan_pwm_1));
    pwm_Nfreq_Nstep pwm2 (.clk(clk), .reset_p(reset_p), .duty(fan2_on ? 8'd200 : 0), .pwm(fan_pwm_2));

    // [표시 로직] 7세그먼트 데이터 선택 (SW1)
    always @(*) begin
        if(sw_select) begin disp_temp = temp2; disp_humi = humi2; end
        else begin disp_temp = temp1; disp_humi = humi1; end
    end
    assign led_sw_state = sw_select;
    fnd_4digit_control fnd (.clk(clk), .reset_p(reset_p), .value_left(disp_temp), .value_right(disp_humi), .seg(seg), .an(an));

    // [VGA 시각화]
    wire [9:0] x, y; 
    wire v_on;
    wire [1:0] st1 = (temp1 == 0) ? 2'b00 : (fan1_on ? 2'b10 : 2'b01);
    wire [1:0] st2 = (temp2 == 0) ? 2'b00 : (fan2_on ? 2'b10 : 2'b01);
    
    vga_controller u_vga_sync (
        .clk(clk), .reset_p(reset_p), 
        .hsync(hsync), .vsync(vsync), 
        .video_on(v_on), .pixel_x(x), .pixel_y(y)
    );

    // 인스턴스 이름을 u_vga_draw로 수정하여 vga_g 포트와 충돌 방지
    vga_pixel_gen u_vga_draw (
        .x(x), .y(y), .v_on(v_on), 
        .st1(st1), .st2(st2), 
        .v_r(vga_r), .v_g(vga_g), .v_b(vga_b)
    );

endmodule

// ==========================================================
// 2. VGA PIXEL GENERATOR: 박스 및 숫자 렌더링
// ==========================================================
module vga_pixel_gen(
    input [9:0] x, y, input v_on,
    input [1:0] st1, st2,
    output reg [3:0] v_r, v_g, v_b
);
    wire box1 = (x >= 150 && x <= 270 && y >= 180 && y <= 300);
    wire box2 = (x >= 370 && x <= 490 && y >= 180 && y <= 300);
    
    wire num1 = (x >= 205 && x <= 215 && y >= 210 && y <= 270);
    wire num2 = (x >= 410 && x <= 450 && y >= 210 && y <= 215) || (x >= 445 && x <= 450 && y >= 210 && y <= 240) ||
                (x >= 410 && x <= 450 && y >= 238 && y <= 243) || (x >= 410 && x <= 415 && y >= 240 && y <= 270) ||
                (x >= 410 && x <= 450 && y >= 265 && y <= 270);

    always @(*) begin
        if (!v_on) begin v_r = 0; v_g = 0; v_b = 0; end
        else if (box1) begin
            if (num1) {v_r, v_g, v_b} = 12'hFFF;
            else begin
                case(st1)
                    2'b10: {v_r, v_g, v_b} = 12'h0F0; // Green
                    2'b01: {v_r, v_g, v_b} = 12'h00F; // Blue
                    default: {v_r, v_g, v_b} = 12'hF00; // Red
                endcase
            end
        end else if (box2) begin
            if (num2) {v_r, v_g, v_b} = 12'hFFF;
            else begin
                case(st2)
                    2'b10: {v_r, v_g, v_b} = 12'h0F0; // Green
                    2'b01: {v_r, v_g, v_b} = 12'h00F; // Blue
                    default: {v_r, v_g, v_b} = 12'hF00; // Red
                endcase
            end
        end else begin
            v_r = 4'h1; v_g = 4'h1; v_b = 4'h1; // 배경색
        end
    end
endmodule

// ==========================================================
// 3. VGA CONTROLLER
// ==========================================================
module vga_controller(
    input clk, reset_p, output hsync, vsync, video_on, output [9:0] pixel_x, pixel_y
);
    reg [1:0] clk_div; wire p_clk = (clk_div == 3);
    always @(posedge clk) clk_div <= clk_div + 1;
    reg [9:0] h_cnt, v_cnt;
    always @(posedge clk) if(p_clk) begin
        if(h_cnt == 799) begin h_cnt <= 0; if(v_cnt == 524) v_cnt <= 0; else v_cnt <= v_cnt + 1; end
        else h_cnt <= h_cnt + 1;
    end
    assign hsync = ~(h_cnt >= 656 && h_cnt <= 751);
    assign vsync = ~(v_cnt >= 490 && v_cnt <= 491);
    assign video_on = (h_cnt < 640 && v_cnt < 480);
    assign pixel_x = h_cnt; assign pixel_y = v_cnt;
endmodule

// ==========================================================
// 4. FND CONTROL (7-Segment)
// ==========================================================
module fnd_4digit_control(
    input clk, reset_p, input [7:0] value_left, value_right,
    output reg [7:0] seg, output reg [3:0] an
);
    wire [3:0] d3 = value_left / 10, d2 = value_left % 10, d1 = value_right / 10, d0 = value_right % 10;
    reg [16:0] clk_div; always @(posedge clk) clk_div <= clk_div + 1;
    always @(*) begin
        case(clk_div[16:15])
            2'b00: begin an = 4'b0111; seg = fnd_dec(d3); end
            2'b01: begin an = 4'b1011; seg = fnd_dec(d2); end
            2'b10: begin an = 4'b1101; seg = fnd_dec(d1); end
            2'b11: begin an = 4'b1110; seg = fnd_dec(d0); end
        endcase
    end
    function [7:0] fnd_dec(input [3:0] n);
        case(n) 0:fnd_dec=8'hC0; 1:fnd_dec=8'hF9; 2:fnd_dec=8'hA4; 3:fnd_dec=8'hB0;
                4:fnd_dec=8'h99; 5:fnd_dec=8'h92; 6:fnd_dec=8'h82; 7:fnd_dec=8'hF8;
                8:fnd_dec=8'h80; 9:fnd_dec=8'h90; default:fnd_dec=8'hFF; endcase
    endfunction
endmodule

// ==========================================================
// 5. DHT11 & UTILITIES (PWM, Edge Detector, etc.)
// ==========================================================
module dht11_cntr(
    input clk, reset_p, inout dht11_data,
    output reg [7:0] temperature, humidity
);
    localparam S_IDLE=0, S_LOW_18MS=1, S_HIGH_20US=2, S_LOW_80US=3, S_HIGH_80US=4, S_READ=5;
    wire clk_usec, d_n, d_p; reg [21:0] u_cnt; reg u_en, d_out_en, d_out;
    assign dht11_data = d_out_en ? d_out : 1'bz;
    clock_usec cv(clk, reset_p, clk_usec);
    edge_detector_p ed(.clk(clk), .reset_p(reset_p), .cp(dht11_data), .p_edge(d_p), .n_edge(d_n));
    reg [2:0] state; reg [39:0] t_raw; reg [5:0] b_cnt; reg r_st;
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin state <= S_IDLE; temperature <= 0; humidity <= 0; b_cnt <= 0; u_en <= 0; end
        else begin
            if(clk_usec && u_en) u_cnt <= u_cnt + 1;
            case(state)
                S_IDLE: begin u_en <= 1; d_out_en <= 0; if(u_cnt >= 2000000) begin u_cnt <= 0; state <= S_LOW_18MS; end end
                S_LOW_18MS: begin d_out_en <= 1; d_out <= 0; if(u_cnt >= 20000) begin u_cnt <= 0; d_out_en <= 0; state <= S_HIGH_20US; end end
                S_HIGH_20US: if(d_n) begin u_cnt <= 0; state <= S_LOW_80US; end
                S_LOW_80US: if(d_p) state <= S_HIGH_80US;
                S_HIGH_80US: if(d_n) state <= S_READ;
                S_READ: begin
                    if(d_p) begin r_st <= 1; u_cnt <= 0; end
                    if(r_st && d_n) begin t_raw <= {t_raw[38:0], (u_cnt > 50)}; b_cnt <= b_cnt + 1; r_st <= 0; end
                    if(b_cnt >= 40) begin humidity <= t_raw[39:32]; temperature <= t_raw[23:16]; state <= S_IDLE; b_cnt <= 0; u_cnt <= 0; end
                end
            endcase
        end
    end
endmodule

module clock_usec(input clk, reset_p, output clk_u);
    reg [6:0] c; always @(posedge clk) if(c>=99) c<=0; else c<=c+1;
    assign clk_u = (c==99);
endmodule

module edge_detector_p(input clk, reset_p, cp, output p_edge, output n_edge);
    reg f1, f2; always @(posedge clk) {f2, f1} <= {f1, cp};
    assign p_edge = (f2==0 && f1==1); assign n_edge = (f2==1 && f1==0);
endmodule

module pwm_Nfreq_Nstep(input clk, reset_p, input [7:0] duty, output pwm);
    reg [7:0] c; always @(posedge clk) c <= c + 1;
    assign pwm = (c < duty);
endmodule
