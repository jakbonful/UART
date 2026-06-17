vlib work
vmap work work
vlog rtl/baudrate_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/tb_uart_top.v
vsim work.tb_uart_top
add wave -position end sim:/tb_uart_top/*
run -all