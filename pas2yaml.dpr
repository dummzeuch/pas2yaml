program pas2yaml;

{$APPTYPE CONSOLE}

//tip: for testing, use these params (simulation without shell)
//  pas2yaml.exe shell test.flag
//and enter the following lines in the commandline:
// ./test/src.pas
// UTF-8
// ./test/result.pas

uses
  Windows,
  Classes,
  SysUtils,
  IOUtils,
  SemanticYaml in 'SemanticYaml.pas',
  PasToYamlParser in 'PasToYamlParser.pas';

var
  DebugFn: string = '';

procedure DebugLog(const _s: string);
begin
{$IFDEF DEBUG}
  TFile.AppendAllText(DebugFn, _s + #13);
{$ENDIF}
end;

///<summary>
/// Reads a line from stdin
/// @param Line is the line that was read
/// @returns true, if a line could be read
///          false, if 'end' was read
/// @raises Exception if INPUT reaches EOF or more the 10 empty lines were read. </summary>

function TryReadLine(out _Line: string): boolean;
const
  MaxEmptyCnt = 10;
var
  EmptyCnt: Integer;
begin
  Result := False;
  _Line := '';
  EmptyCnt := 0;
  while _Line = '' do begin
    if Eof(INPUT) then
      raise Exception.Create('Exiting because INPUT reached EOF.');
    ReadLn(_Line);
    DebugLog('Received line: ' + _Line);
    _Line := Trim(_Line);
    if SameText(_Line, 'end') then
      Exit; //==>
    if _Line = '' then begin
      inc(EmptyCnt);
      if EmptyCnt >= MaxEmptyCnt then
        raise Exception.CreateFmt('Exiting after reading %d empty lines', [EmptyCnt]);
    end;
  end;
  Result := True;
end;

function TryReadFileSet(out _InputFn, _Encoding, _OutputFn: string): boolean;
begin
  Result := TryReadLine(_InputFn)
    and TryReadLine(_Encoding)
    and TryReadLine(_OutputFn);
end;

var
  sFlagFile: string;
  GivenEncoding: string;
  sFileToParse: string;
  sOutputFile: string;
  parser: TPas2YamlParser;
  strmstring: TStringStream;
  strmstring2: TStringStream;
  sData: string;
begin
{$IFDEF EXTERNALDEBUG}
  MessageBox(0, PChar('attach debugger now'), PChar(''), MB_ICONWARNING or MB_OK);
{$ENDIF}

  try
    DebugFn := paramstr(0) + '-debug.log';
    sFileToParse := '';
    GivenEncoding := '';
    sOutputFile := '';
    // there are two arguments to consider:
    // 1) "shell" saying you must run in "shell mode"
    //    - don't exit basically and wait for commands
    // 2) A "flag file" - write it when you're done just
    //    in case you need initialization (like starting
    //    up the Java VM)
    if ParamCount < 1 then
      raise Exception.Create('Required parameters are missing.');
    if ParamCount > 2 then
      raise Exception.Create('Unexpected additional parameters.');

    if not SameText('shell', paramstr(1)) then
      raise Exception.Create('Required first parameter "shell" is missing.');

    if ParamCount = 2 then
      sFlagFile := paramstr(2)
    else
      sFlagFile := '';

    //create stuff
    parser := TPas2YamlParser.Create;
    strmstring := TStringStream.Create;
    try
      // Write the "flagfile" when you're ready
      if sFlagFile <> '' then
        TFile.WriteAllText(sFlagFile, 'READY');
      DebugLog('READY');

      // Loop until Semantic writes "end"
      while TryReadFileSet(sFileToParse, GivenEncoding, sOutputFile) do begin
        DebugLog('Received inputfile: ' + sFileToParse);
        DebugLog('Received encoding: ' + GivenEncoding);
        DebugLog('Received outputfile: ' + sOutputFile);

        if FileExists(sOutputFile) then
          raise Exception.Create('Output file already exists, cowardly refusing to overwrite it.');

        // load the file
        strmstring.LoadFromFile(sFileToParse);
        sData := strmstring.DataString;
        strmstring.Clear;
        // we convert the string to unicode string (utf16) because parser needs this
        strmstring2 := TStringStream.Create(sData, TEncoding.Unicode);
        try
          strmstring2.Position := 0;
          // Parse the "fileToParse"
          try
            parser.Run(sFileToParse, strmstring2);
          except
            parser.Yaml.parsingErrorsDetected := True;
          end;
        finally
          strmstring2.Free;
        end;

        DebugLog('Parsed and writing to outputfile: ' + sOutputFile);
        // Write the result to "outputFile"
        TFile.WriteAllText(sOutputFile, parser.Yaml.Generate(''));
        // write OK when you're done or KO if it didn't work
        WriteLn('OK');
        Flush(Output); //important!

        DebugLog('wrote OK');
        DebugLog('READY');
      end;
    finally
      strmstring.Free;
      parser.Free;
    end;

  except
    on E: Exception do begin
      DebugLog('Exception: ' + E.classname + ' ' + E.Message);

      WriteLn('KO');
      WriteLn(E.classname, ': ', E.Message);
      Flush(Output); //important!

      DebugLog('wrote KO');
    end;
  end;
end.

