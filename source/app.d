module yeti16.app;

import std.utf;
import std.conv;
import std.file;
import std.stdio;
import std.string;
import yeti16.util;
import yeti16.emulator;
import yeti16.assembler.lexer;
import yeti16.assembler.parser;
import yeti16.assembler.assembler;

const string appUsage = "
Usage: %s OPERATION [flags]

Operations:
	run FILE [read flags]      - runs the given binary file in the emulator
	asm FILE [-o out_file.bin] - assembles the given file (to \"out.bin\" by default)
	new_disk FILE SECTORS      - creates a disk at FILE with SECTORS sectors

Run flags:
	--serial         : Enables the serial port (port 4040)
	--allow-ip <IP>  : Adds an IP to the serial port whitelist
	--disk <PATH>    : Loads the given disk
	--memdump <FILE> : On exit, YETI-16 writes the whole contents of memory to FILE
";

void main(string[] args) {
	if (args.length == 0) {
		stderr.writeln("use a different shell");
		exit(1);
	}

	if (args.length == 1) {
		writefln(appUsage.strip(), args[0]);
		exit(0);
	}

	switch (args[1]) {
		case "run": {
			if (args.length < 3) {
				stderr.writeln("Emulator needs FILE parameter");
				exit(1);
			}

			auto    emulator = new Emulator(args);
			ubyte[] program;

			try {
				program = cast(ubyte[]) read(args[2]);
			}
			catch (FileException e) {
				stderr.writefln("%s: %s", args[2], e.msg);
				exit(1);
			}

			emulator.LoadData(0x050000, program);

			emulator.Run();
			emulator.DumpState();
			break;
		}
		case "asm": {
			string file;
			string outFile = "out.bin";

			for (size_t i = 2; i < args.length; ++ i) {
				if (args[i][0] == '-') {
					switch (args[i]) {
						case "-o": {
							++ i;
							outFile = args[i];
							// TODO: check
							break;
						}
						default: {
							stderr.writefln("Unknown flag '%s'", args[i]);
							exit(1);
						}
					}
				}
				else {
					file = args[i];
				}
			}

			if (file.strip() == "") {
				stderr.writeln("Assembler needs FILE parameter");
				exit(1);
			}

			string code;
			try {
				code = readText(file);
			}
			catch (FileException e) {
				stderr.writefln("%s: %s", file, e.msg);
				exit(1);
			}
			catch (UTFException e) {
				stderr.writefln("%s: %s", file, e.msg);
				exit(1);
			}

			auto lexer     = new Lexer();
			auto parser    = new Parser();
			auto assembler = new Assembler();
			lexer.code     = code;
			lexer.file     = file;
			lexer.Lex();

			parser.tokens = lexer.tokens;
			parser.Parse();

			assembler.nodes = parser.nodes;
			try {
				assembler.Assemble();
			}
			catch (AssemblerError) {
				exit(1);
			}

			std.file.write(outFile, assembler.bin);
			break;
		}
		case "new_disk": {
			if (args.length != 4) {
				stderr.writeln("2 parameters (FILE, SECTORS) required for new_disk");
				exit(1);
			}
			if (!args[3].isNumeric()) {
				stderr.writeln("SECTORS parameter isn't numeric");
				exit(1);
			}

			auto path    = args[2];
			auto sectors = parse!uint(args[3]);

			auto file = File(path, "wb");

			foreach (i ; 0 .. sectors) {
				file.rawWrite(new ubyte[512]);
				writef("\r[%d/%d] Writing sectors", i + 1, sectors);
				stdout.flush();
			}
			writeln();
			break;
		}
		default: {
			stderr.writefln("Unknown operation '%s'", args[1]);
			exit(1);
		}
	}
}
