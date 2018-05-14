all: fpga jic

#altera_quartus/RobotLeon2.sof: 
fpga:
	/opt/altera/13.0sp1/quartus/bin/quartus_sh --64bit --flow compile altera_quartus/RobotLeon2.qpf

#fpga: altera_quartus/RobotLeon2.sof

#altera_quartus/RobotLeon2.jic: altera_quartus/RobotLeon2.sof
jic:
	/opt/altera/13.0sp1/quartus/bin/quartus_cpf -c -d EPCS64 -s EP4CE22 altera_quartus/output_files/RobotLeon2.sof altera_quartus/output_files/RobotLeon2.jic

#jic: altera_quartus/RobotLeon2.jic

prog: 
	/opt/altera/13.0sp1/quartus/bin/quartus_pgm -c "USB-Blaster" -m JTAG -o "P;/opt/altera/13.0sp1/quartus/common/devinfo/programmer/sfl_ep4ce22.sof@1"
	/opt/altera/13.0sp1/quartus/bin/quartus_pgm -c "USB-Blaster" -m JTAG -o "P;altera_quartus/output_files/RobotLeon2.jic@1"

clean:
	./clean.sh

