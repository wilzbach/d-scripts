#!/usr/bin/env dub
/+ dub.sdl:
name "check_phobos"
dependency "libdparse" version="~>0.7.0-alpha9"
+/

import std.stdio;
import std.conv;
import std.string;
import std.file;
import std.regex;
import std.range;
import std.exception;
import std.algorithm;

import dparse.ast;

class TestVisitor : ASTVisitor
{
    File outFile;
    ubyte[] sourceCode;
    string moduleName;
    this(string outFileName, string moduleName, ubyte[] sourceCode)
    {
        this.outFile = File(outFileName, "w");
        this.moduleName = moduleName;
        this.sourceCode = sourceCode;
    }
    alias visit = ASTVisitor.visit;
	override void visit(const Unittest u)
	{
	    // scan the previous line for ddoc header
	    auto loc = u.location + 0;
	    while (sourceCode[loc] != '\n')
            loc--;
	    loc--;
	    auto ddoc = 0;
	    while (sourceCode[loc] != '\n')
	        if (sourceCode[loc--] == '/')
	            ddoc++;

        if (ddoc < 3)
            return;

        outFile.write("unittest\n{\n");
        outFile.write("import ");
        outFile.write(moduleName);
        outFile.write(";");
        outFile.write(cast(char[]) sourceCode[u.blockStatement.startLocation + 1 .. u.blockStatement.endLocation]);
        outFile.write("\n}\n");
	}
}

void parseTests(string fileName, string moduleName, string outFileName)
{
    import dparse.lexer;
    import dparse.parser;
    import dparse.rollback_allocator;

    import std.array: uninitializedArray;
    assert(exists(fileName));

	File f = File(fileName);
	ubyte[] sourceCode = uninitializedArray!(ubyte[])(to!size_t(f.size));
	f.rawRead(sourceCode);
	LexerConfig config;
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	auto tokens = getTokensForParser(sourceCode, config, &cache);
	RollbackAllocator rba;
	Module m = parseModule(tokens.array, fileName, &rba);
	auto visitor = new TestVisitor(outFileName, moduleName, sourceCode);
	visitor.visit(m);
}

void parseFile(string phobosDir, string fileName, string outputDir, string modulePrefix = "")
{
    import std.path: buildPath, dirSeparator, buildNormalizedPath;
    string fileNameNormalized = fileName.replace(phobosDir, "")[1..$];
    writeln(fileNameNormalized);
    string filePrefix = fileNameNormalized.replace(".d", "").replace(dirSeparator, ".");
    string moduleName = modulePrefix ~ filePrefix.replace(".package", "");

    string outName = fileNameNormalized.replace("./", "").replace(dirSeparator, "_");
    parseTests(fileName, moduleName, buildPath(outputDir, outName));
}

void main(string[] args){
    enforce(args.length > 1, "Please specify Phobos directory");

    string phobosDir = args[1];
    string outputDir = "./out";

    if (!exists(outputDir))
        mkdir(outputDir);

    auto files = dirEntries(phobosDir, SpanMode.depth).array
                    .filter!(a => a.name().endsWith(".d") &&
                                  !a.name().canFind(".git"));
    foreach (file; files)
    {
        writeln("parsing ", file);
        parseFile(phobosDir, file, outputDir);
    }
}
