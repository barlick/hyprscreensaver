program hyprscreensaver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp, process, DateUtils
  { you can add units after this };

type

  { Thyprscreensave }

  Thyprscreensave = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ Thyprscreensave }

procedure Thyprscreensave.DoRun;
var
  ErrorMsg: String;
  Process1 : TProcess;
  finished : boolean;
  InitialCommandStatusResult,thisCommandStatus,RunningCommandStatus : TStringList;
  getout : boolean;
  temp,swayidledelayseconds : string;
  f : textfile;
  lastruntime,thislastruntime : TDateTime;

  procedure GetRunningStatus(cmd:String);
  var
   t:TProcess;
   s:TStringList;
  begin
    RunningCommandStatus.text := '';
    t:=tprocess.create(nil);
    t.Executable:='ps';
    t.Parameters.Clear;
    t.Parameters.Add('-C');
    t.Parameters.Add(cmd);
    t.Options:=[poUsePipes,poWaitonexit];
    try
     t.Execute;
     s:=tstringlist.Create;
     try
      s.LoadFromStream(t.Output);
      RunningCommandStatus.text := s.text;

      (*
      if cmd = 'swayidle' then
       begin
        t.Executable := 'hyprctl';
        t.Parameters.Clear;
        t.Parameters.Add('notify 0 10000 0 "fontsize:20 Lines:'+inttostr(s.Count)+' <= 1 = RUN');
        t.Options:=[poUsePipes,poWaitonexit];
        t.Execute;
       end;
      *)
     finally
     s.free;
     end;
    finally
    t.Free;
    end;
  end;

 procedure GetCommandStatus(cmd:String);
 var
  t:TProcess;
  s:TStringList;
 begin
   thisCommandStatus.text := '';
   t:=tprocess.create(nil);
   t.Executable:='ps';
   t.Parameters.Clear;
   t.Parameters.Add('-C');
   t.Parameters.Add(cmd);
   t.Options:=[poUsePipes,poWaitonexit];
   try
    t.Execute;
    s:=tstringlist.Create;
    try
     s.LoadFromStream(t.Output);
     thisCommandStatus.text := inttostr(s.Count); // Just return the number of lines of text returned by "ps" command.
    finally
    s.free;
    end;
   finally
   t.Free;
   end;
 end;

begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }

  // Read the swayidle wait time in seconds from ~/.config/hypr/hyprscreensaver.conf
  // If it's not present then create it and put defaults in.
  swayidledelayseconds := '900'; // Default is 15 minutes.
  lastruntime := now; thislastruntime := 0;
  if fileexists('/home/barlick/.config/hypr/hyprscreensaver.conf') then
   begin
    assignfile(f,'/home/barlick/.config/hypr/hyprscreensaver.conf');
    reset(f);
    while not eof(f) do
     begin
      readln(f,temp);
      if pos('DELAY IN SECONDS:',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'DELAY IN SECONDS:','',[rfreplaceall,rfignorecase]);
         swayidledelayseconds := temp;
        end
        else if pos('LAST RUN TIME:',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'LAST RUN TIME:','',[rfreplaceall,rfignorecase]);
         thislastruntime := strtodatetime(temp);
        end;
     end;
    close(f);
   end;

  getout := false;

  // Is the difference between "now" (lastruntime) and the last run time read from the conf file (thislastruntime) < 10 seconds then it's a "misfire" so get out.
  if thislastruntime <> 0 then
   begin
    if lastruntime - thislastruntime > 0 then
      begin
       if lastruntime - thislastruntime < 0.000115740740740741 then // 10 seconds = 0.000115740740740741
        begin
         getout := true;
        end;
      end;
   end;

  // Is hyprscreensaver already running? If so then quit (getout=true):
  RunningCommandStatus := TStringList.create;
  RunningCommandStatus.text := '';
  GetRunningStatus('hyprscreensaver');
  if RunningCommandStatus.Count > 2 then
   begin
    getout := true;
   end;

  // Is swayidle NOT running? If so then start it up and then quit (getout=true):
  if not getout then
    begin
      RunningCommandStatus := TStringList.create;
      RunningCommandStatus.text := '';
      GetRunningStatus('swayidle');
      if RunningCommandStatus.Count <= 1 then
       begin
        // No running so start it.
        Process1 := TProcess.Create(nil);
        try
          Process1.Executable:='hyprctl';
          Process1.Parameters.Clear;
          Process1.Parameters.Add('dispatch');
          Process1.Parameters.Add('exec');
          Process1.Parameters.Add('swayidle -w timeout '+swayidledelayseconds+' ~/Documents/hyprscreensaver');
          Process1.Options := [poUsePipes];
          Process1.Execute;
        finally
         Process1.Free;
        end;
        getout := true;
       end;
    end;

  if not getout then
   begin
    Process1 := TProcess.Create(nil);
    try
      // Kill swayidle to stop it running until this instance of hyprscreensaver has finished.
      Process1.Executable:='pkill';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('swayidle');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch to 1st monitor:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 8:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('8');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Launch screensaver video in ffplay on 1st monitor on workspace 8 using Process1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('ffplay ~/Documents/screensaver.mp4 -fs -exitonkeydown -exitonmousedown -loop 0');
      Process1.Options := [poUsePipes];
      Process1.Execute;

      // Switch to 2nd monitor:
      sleep(200);
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 9:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('9');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Launch screensaver video in ffplay on 2ns monitor on workspace 8 using Process1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('ffplay ~/Documents/screensaver.mp4 -fs -exitonkeydown -exitonmousedown -loop 0');
      Process1.Options := [poUsePipes];
      Process1.Execute;

      sleep(200);
      finished := false;
      InitialCommandStatusResult := TStringList.Create;
      InitialCommandStatusResult.Text:='';
      thisCommandStatus := TStringList.create;
      thisCommandStatus.text := '';
      GetCommandStatus('ffplay');
      InitialCommandStatusResult.text := thisCommandStatus.text;
      //memo1.text := '';
      repeat
        sleep(200);
        GetCommandStatus('ffplay');
        if (InitialCommandStatusResult.text <> thisCommandStatus.text) then
        begin
          finished := true;
        end;
      until finished;

      // Switch to 1st monitor:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      sleep(200);

      // Kill all ffplay processes:
      Process1.Executable:='pkill';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('ffplay');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch to 2nd monitor:
      sleep(200);
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 2:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Write out the hyprscreensaver.conf with updated values (mainly want "Last run time"):
      lastruntime := now;
      assignfile(f,'/home/barlick/.config/hypr/hyprscreensaver.conf');
      rewrite(f);
      writeln(f,'Delay in seconds:'+swayidledelayseconds);
      writeln(f,'Last run time:'+datetimetostr(lastruntime));
      close(f);

      // Re-start swayidle:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('swayidle -w timeout '+swayidledelayseconds+' ~/Documents/hyprscreensaver');
      Process1.Options := [poUsePipes];
      Process1.Execute;

    finally
     Process1.Free;
     InitialCommandStatusResult.free;
     thisCommandStatus.free;
     RunningCommandStatus.free;
     // finished then close;
    end;
   end;

  // stop program loop
  Terminate;
end;

constructor Thyprscreensave.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor Thyprscreensave.Destroy;
begin
  inherited Destroy;
end;

procedure Thyprscreensave.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: Thyprscreensave;
begin
  Application:=Thyprscreensave.Create(nil);
  Application.Title:='hyprscreensaver';
  Application.Run;
  Application.Free;
end.

