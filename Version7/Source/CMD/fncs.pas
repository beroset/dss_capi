{
 ----------------------------------------------------------
  Copyright (c) 2017-2019 Battelle Memorial Institute
 ----------------------------------------------------------
}
unit FNCS;

{$mode delphi}
//{$mode objfpc}{$H+}
//{$MODESWITCH ADVANCEDRECORDS}
{$MACRO ON}
{$IFDEF Windows}
{$DEFINE FNCS_CALL:=stdcall}
//{$DEFINE FNCS_CALL:=cdecl}
{$ELSE} // Darwin and Unix
{$DEFINE FNCS_CALL:=cdecl}
{$ENDIF}

interface

uses
  Classes, SysUtils, Executive, {$IFDEF Unix} unix, {$ENDIF} dynlibs, DSSGlobals,
  UComplex, generics.collections, CktElement, Utilities, math,
  RegControl,ControlElem;

type
  fncs_time = qword;

  // dictionaries of FNCS output topics, with indices into the corresponding OpenDSS lists
  ConductorValueDict = TDictionary<string, string>;
  TerminalConductorDict = TObjectDictionary<string, ConductorValueDict>;
  AttributeTerminalDict = TObjectDictionary<string, TerminalConductorDict>;
  TFNCSMap = class(TObject)
  public
    atd: AttributeTerminalDict; // hierarchy of attributes, terminals and values to publish
    idx: Integer;             // cached index of oad.key into ActiveCircuit.BusList or DeviceList
    constructor Create();
  end;
  ObjectAttributeDict = TObjectDictionary<string, TFNCSMap>;
  ClassObjectDict = TObjectDictionary<string, ObjectAttributeDict>;

  TFNCS = class(TObject)
  private
    FLibHandle: TLibHandle;
    FuncError: Boolean;
    // Connect to broker and parse config file.
    fncs_initialize: procedure;FNCS_CALL;
    // Connect to broker and parse inline configuration.
    fncs_initialize_config: procedure (configuration:Pchar);FNCS_CALL;
    // Connect to broker and parse config file for Transactive agents.
    fncs_agentRegister: procedure;FNCS_CALL;
    // Connect to broker and parse inline configuration for transactive agents.
    fncs_agentRegisterConfig: procedure (configuration:Pchar);FNCS_CALL;
    // Check whether simulator is configured and connected to broker.
    fncs_is_initialized: function:longint;FNCS_CALL;
    // Request the next time step to process.
    fncs_time_request: function (next:fncs_time):fncs_time;FNCS_CALL;
    // Publish value using the given key.
    fncs_publish: procedure (key:Pchar; value:Pchar);FNCS_CALL;
    // Publish value anonymously using the given key.
    fncs_publish_anon: procedure (key:Pchar; value:Pchar);FNCS_CALL;
    // Publish function for transactive agents.
    fncs_agentPublish: procedure (value:Pchar);FNCS_CALL;
    // Publish value using the given key, adding from:to into the key.
    fncs_route: procedure (source:Pchar; target:Pchar; key:Pchar; value:Pchar);FNCS_CALL;
    // Tell broker of a fatal client error.
    fncs_die: procedure;FNCS_CALL;
    // Close the connection to the broker.
    fncs_finalize: procedure;FNCS_CALL;
    // Update minimum time delta after connection to broker is made. Assumes time unit is not changing.
    fncs_update_time_delta: procedure (delta:fncs_time);FNCS_CALL;
    // Get the number of keys for all values that were updated during the last time_request.
    fncs_get_events_size: function:size_t;FNCS_CALL;
    // Get the keys for all values that were updated during the last time_request.
    fncs_get_events: function:ppchar;FNCS_CALL;
    // Get one key for the given event index that as updated during the last time_request.
    fncs_get_event_at: function (index:size_t):pchar;FNCS_CALL;
    // Get the agent events for all values that were updated during the last time_request.
    fncs_agentGetEvents: function:pchar;FNCS_CALL;
    // Get a value from the cache with the given key. Will hard fault if key is not found.
    fncs_get_value: function (key:Pchar):pchar;FNCS_CALL;
    // Get the number of values from the cache with the given key.
    fncs_get_values_size: function (key:Pchar):size_t;FNCS_CALL;
    // Get an array of values from the cache with the given key. Will return an array of size 1 if only a single value exists.
    fncs_get_values: function (key:Pchar):ppchar;FNCS_CALL;
    // Get a single value from the array of values for the given key.
    fncs_get_value_at: function (key:Pchar; index:size_t):pchar;FNCS_CALL;
    // Get the number of subscribed keys.
    fncs_get_keys_size: function:size_t;FNCS_CALL;
    // Get the subscribed keys. Will return NULL if fncs_get_keys_size() returns 0.
    fncs_get_keys: function:ppchar;FNCS_CALL;
    // Get the subscribed key at the given index. Will return NULL if fncs_get_keys_size() returns 0.
    fncs_get_key_at: function (index:size_t):pchar;FNCS_CALL;
    // Return the name of the simulator.
    fncs_get_name: function:pchar;FNCS_CALL;
    // Return a unique numeric ID for the simulator.
    fncs_get_id: function:longint;FNCS_CALL;
    // Return the number of simulators connected to the broker.
    fncs_get_simulator_count: function:longint;FNCS_CALL;
    // Run-time API version detection.
    fncs_get_version: procedure (major:Plongint; minor:Plongint; patch:Plongint);FNCS_CALL;
    // Convenience wrapper around libc free.
    fncs_free: procedure (ptr:pointer);FNCS_CALL;

    function find_fncs_function (name: String): Pointer;

  private
    next_fncs_publish:fncs_time;
    topics:ClassObjectDict;
    fncsOutputStream:TStringStream;

  public
    PublishInterval:Integer;
    PublishMode:string;
    FedName:string;
    FNCSTopicsMapped:Boolean;

    function IsReady:Boolean;
    procedure RunFNCSLoop (const s:string);
    constructor Create();
    destructor Destroy; override;
    function FncsTimeRequest (next_fncs:fncs_time):Boolean;
    procedure ReadFncsPubConfig (fname: string);
    procedure MapFNCSTopics;
    procedure DumpFNCSTopics;
//    procedure GetCurrentValuesForTopics;   
//    procedure GetCurrentValuesForTopics2;
//    procedure GetVoltageValuesForTopics;
    procedure GetValuesForTopics;
//    procedure GetPowerValuesForTopics;
    procedure TopicsToJsonStream;
//    procedure AddCurrentsToDict(pElem:TDSSCktElement;Cbuffer:pComplexArray;topics:ClassObjectDict);
//    procedure AddCurrentsToDict2(pElem:TDSSCktElement;topics:ClassObjectDict);
//    procedure AddPowersToDict(pElem:TDSSCktElement;topics:ClassObjectDict);
    function RoundToSignificantFigure(value:double;digit:Integer):double;
//    procedure GetTapPositionsForTopics;
//    procedure GetControlStatusForTopics;
//    procedure GetLineSwitchStateForTopics;
  end;

var
  ActiveFNCS:TFNCS;

implementation

uses
  fpjson, jsonparser, jsonscanner;

constructor TFNCSMap.Create;
begin
  idx := 0;
  atd := AttributeTerminalDict.create([doOwnsValues]);
end;

FUNCTION  InterpretStopTimeForFNCS(const s:string):fncs_time;
Var
  Code :Integer;
  ch :char;
  s2 :String;
Begin
  {Adapted from InterpretTimeStepSize}
  val(s,Result, Code);
  If Code = 0 then Exit; // Only a number was specified, so must be seconds

  {Error occurred so must have a units specifier}
  ch := s[Length(s)];  // get last character
  s2 := copy(s, 1, Length(s)-1);
  Val(S2, Result, Code);
  If Code>0 then Begin
    writeln('Error in FNCS Stop Time: ' + s);
    Exit;
  End;
  case ch of
    'd': Result := Result * 86400;
    'h': Result := Result * 3600;
    'm': Result := Result * 60;
    's':; // still seconds
  Else
    writeln('Error in FNCS Stop Time: "' + s +'" Units can only be d, h, m, or s (single char only)');
  end;
End;
          
{*
procedure TFNCS.GetCurrentValuesForTopics;

  Var
      F          :TextFile;
      cBuffer    :pComplexArray;
      pElem      :TDSSCktElement;
      MaxCond, MaxTerm   :Integer;
      i,j        :Integer;

  Begin

    cBuffer := nil;

    Try
       Getmem(cBuffer, sizeof(cBuffer^[1])*GetMaxCktElementSize);

       // Sources first
       pElem := ActiveCircuit.Sources.First;
       WHILE pElem<>nil DO BEGIN
         IF pElem.Enabled THEN BEGIN
            pElem.GetCurrents(cBuffer);
            AddCurrentsToDict(pElem, Cbuffer, topics);
         END;
          pElem := ActiveCircuit.Sources.Next;
       END;


       // PDELEMENTS first
       pElem := ActiveCircuit.PDElements.First;
       WHILE pElem<>nil DO BEGIN
         IF pElem.Enabled THEN BEGIN
          pElem.GetCurrents(cBuffer);
          AddCurrentsToDict(pElem, Cbuffer, topics);
         END;
          pElem := ActiveCircuit.PDElements.Next;
       END;

       // Faults
       pElem := ActiveCircuit.Faults.First;
       WHILE pElem<>nil DO BEGIN
         IF pElem.Enabled THEN BEGIN
          pElem.GetCurrents(cBuffer);
          AddCurrentsToDict(pElem, Cbuffer, topics);
         END;
          pElem := ActiveCircuit.Faults.Next;
       END;

       // PCELEMENTS next
       pElem := ActiveCircuit.PCElements.First;
       WHILE pElem<>nil DO BEGIN
         IF pElem.Enabled THEN BEGIN
          pElem.GetCurrents(cBuffer);
          AddCurrentsToDict(pElem, Cbuffer, topics);
         END;
          pElem := ActiveCircuit.PCElements.Next;
       END;
    FINALLY
       If Assigned(cBuffer) Then Freemem(cBuffer);
    End;
  End;

PROCEDURE TFNCS.AddCurrentsToDict(pelem:TDSSCktElement; Cbuffer:pComplexArray; topics:ClassObjectDict);
VAr
    i,j,k:Integer;
    value:Complex;
    cls,obj,terminal,conductor,jstr,istr,sign:string;

Begin
    k:=0;
    cls:=LowerCase(pelem.DSSClassName);
    obj:=LowerCase(pelem.LocalName);
    if topics.Containskey(cls) and topics[cls].containsKey(obj) then
       For j := 1 to pElem.Nterms Do Begin
         jstr:=IntToStr(j);
         if topics[cls][obj]['current'].ContainsKey(jstr) then
           For i:= 1 to pElem.NConds Do Begin
             Inc(k);
             istr:=IntToStr(i);
             if topics[cls][obj]['current'][jstr].ContainsKey(istr) then
             begin
               value:=cBuffer^[k];
               if value.im < 0 then
                 sign:=''
               else
                 sign:='+';
               topics[cls][obj]['current'][jstr][istr]:=value.re.ToString+sign+value.im.ToString+'i';
             end
           end
         else
           k:=k+pElem.NConds
       END;
End;

procedure TFNCS.GetCurrentValuesForTopics2;
  Var
      F          :TextFile;
      cBuffer    :pComplexArray;
      pElem      :TDSSCktElement;
      i,j        :Integer;

  Begin

    Try

       // Sources first
       pElem := ActiveCircuit.Sources.First;

       WHILE pElem <> nil DO Begin
         IF pElem.Enabled  THEN AddCurrentsToDict2(pElem, topics);
          pElem := ActiveCircuit.Sources.Next;
       End;

       // PDELEMENTS first
       pElem := ActiveCircuit.PDElements.First;

       WHILE pElem<>nil  DO Begin
         IF pElem.Enabled THEN AddCurrentsToDict2(pElem, topics);
          pElem := ActiveCircuit.PDElements.Next;
       End;

       // Faults
       pElem := ActiveCircuit.Faults.First;

       WHILE pElem<>nil DO Begin
         IF pElem.Enabled THEN AddCurrentsToDict2(pElem, topics);
          pElem := ActiveCircuit.Faults.Next;
       End;

       // PCELEMENTS next
       pElem := ActiveCircuit.PCElements.First;

       WHILE pElem<>nil DO Begin
         IF pElem.Enabled THEN AddCurrentsToDict2(pElem, topics);
         pElem := ActiveCircuit.PCElements.Next;
       End;
    FINALLY
    End;
  End;

PROCEDURE TFNCS.AddCurrentsToDict2(pElem:TDSSCktElement; topics:ClassObjectDict);

Var

    j,i,k, Ncond, Nterm, phase:Integer;
    cBuffer :pComplexArray;
    FromBus,cls,obj,jstr,istr,phaseStr,sign:String;
    Ctotal,current:Complex;

BEGIN

  cBuffer := nil;

  NCond := pElem.NConds;
  Nterm := pElem.Nterms;
  cls:=LowerCase(pelem.DSSClassName);
  obj:=LowerCase(pelem.LocalName);

  Try
    //begin
    Getmem(cBuffer, sizeof(cBuffer^[1])*Ncond*Nterm);
    pElem.GetCurrents(cBuffer);
    k:=0;
    //FromBus:=StripExtension(pElem.FirstBus);
    if topics.Containskey(cls) and topics[cls].containsKey(obj) then
      For j:=1 to pElem.Nterms Do begin
        jstr:=IntToStr(j);
        if topics[cls][obj]['current'].containsKey(jstr) then
          For i:=1 to pElem.NConds Do Begin
            Inc(k);
            //istr:=IntToStr(i);
            phase:=GetNodeNum(pElem.NodeRef^[k]);
            case phase of
              1:phaseStr:='A';
              2:phaseStr:='B';
              3:phaseStr:='C';
            else
              phaseStr:=IntToStr(phase);
            end;
            if topics[cls][obj]['current'][jstr].ContainsKey(phaseStr) then begin
              current:= cBuffer^[k];
              if current.im<0 then
                sign:=''
              else
                sign:='+';
              topics[cls][obj]['current'][jstr][phaseStr]:=RoundToSignificantFigure(current.re,6).ToString+sign+RoundToSignificantFigure(current.im,6).toString+'i';
            end
          end
        else
          k:=k+pElem.NConds;
        //end;
      End
      //FromBus := StripExtension(pElem.Nextbus);
  Finally
    If Assigned(cBuffer) Then Freemem(cBuffer);
  End;
END;

procedure TFNCS.GetPowerValuesForTopics;
Var
    pElem :TDSSCktElement;
Begin
     // Sources first
     pElem := ActiveCircuit.sources.First;

     WHILE pElem<>nil DO Begin
       IF pElem.Enabled  THEN AddPowersToDict(pElem, topics);
       pElem := ActiveCircuit.sources.Next;
     End;

     // PDELEMENTS first
     pElem := ActiveCircuit.PDElements.First;
     WHILE pElem<>nil DO Begin
       IF pElem.Enabled  THEN AddPowersToDict(pElem, topics);
       pElem := ActiveCircuit.PDElements.Next;
     End;

     // PCELEMENTS next
     pElem := ActiveCircuit.PCElements.First;
     WHILE pElem<>nil DO Begin
      IF pElem.Enabled  THEN AddPowersToDict(pElem, topics);
       pElem := ActiveCircuit.PCElements.Next;
     End;
end;

procedure TFNCS.AddPowersToDict(pElem:TDSSCktElement; topics:ClassObjectDict);
var
  c_Buffer:pComplexArray;
  FromBus,fullnme,cls,obj,phaseStr,sign,jstr:String;
  NCond, Nterm, i, j, k,phase :Integer;
  Volts:Complex;
  S:Complex;
  nref:Integer;
begin
  c_Buffer:= Nil;
  cls:=LowerCase(pElem.DSSClassName);
  obj:=LowerCase(pElem.LocalName);
  NCond := pElem.NConds;
  Nterm := pElem.Nterms;
  Try
  // Allocate c_Buffer big enough for largest circuit element
    Getmem(c_Buffer, sizeof(c_Buffer^[1])*Ncond*Nterm);
    pElem.GetCurrents(c_Buffer);
    k:=0;
    //FromBus:=StripExtension(pElem.FirstBus);
    fullnme:=FullName(pElem);
    if topics.Containskey(cls) and topics[cls].containsKey(obj) then
      FOR j:=1 to NTerm Do Begin
        jstr:=IntToStr(j);
        if topics[cls][obj]['power'].ContainsKey(jstr) then
          For i:=1 to NCond Do Begin
            Inc(k);
            nref := pElem.NodeRef^[k];
            phase:=GetNodeNum(nref);
            case phase of
              1:phaseStr:='A';
              2:phaseStr:='B';
              3:phaseStr:='C';
            else
              phaseStr:=IntToStr(phase);
            end;
            if topics[cls][obj]['power'][jstr].ContainsKey(phaseStr) then begin
              Volts := ActiveCircuit.Solution.NodeV^[nref];
              S:=Cmul(Volts, conjg(c_Buffer^[k]));
              IF ActiveCircuit.PositiveSequence
              THEN S:=CmulReal(S, 3.0);
              if S.im<0 then
                sign:=''
              else
                sign:='+';
              topics[cls][obj]['power'][jstr][phaseStr]:=RoundToSignificantFigure(S.re*1000,6).ToString+sign+RoundToSignificantFigure(S.im*1000,6).toString+'i';
            end;
          End
        else
          k:=k+pElem.NConds;
      //FromBus:=pElem.Nextbus;
      End;
  Finally
     If Assigned(c_Buffer) then Freemem(c_Buffer);
  End;
end;

procedure TFNCS.GetTapPositionsForTopics;
Var
   iWind :Integer;
   pReg: TRegControlObj;
   //Name:string;
Begin
  Try
     WITH ActiveCircuit Do
     Begin
       pReg := RegControls.First;
       WHILE pReg <> NIL Do
       Begin
          WITH pReg.Transformer Do
          Begin
            iWind := pReg.TrWinding;
            //Name:=PresentTap[iWind];
            if topics['transformer'].ContainsKey(Name) Then
               topics['transformer'][Name]['tapposition']['1']['-1']:=Round((PresentTap[iWind]-(Maxtap[iWind]+Mintap[iWind])/2.0)/TapIncrement[iWind]).ToString();
          End;
          pReg := RegControls.Next;
       End;
     End;
  FINALLY
  End;
end;

PROCEDURE TFNCS.GetControlStatusForTopics;

Var
    ControlDevice:TControlElem;
    parentName,thisName,cls,obj,clsobj:string;
    isClosed,switchFound:Boolean;

Begin
  IF ActiveCircuit <> Nil THEN
    With ActiveCircuit Do Begin
          ControlDevice := Nil;
          switchFound:=false;
          TRY
            // Sample all controls and set action times in control Queue
            ControlDevice := DSSControls.First;
            WHILE ControlDevice <> Nil Do
            Begin
                 parentName:=ControlDevice.ParentClass.Name;
                 thisName:=ControlDevice.Name;
                 obj:=ControlDevice.LocalName;
                 cls:=ControlDevice.DSSClassName;
                 clsobj:=ControlDevice.DisplayName;
                 if parentName<>'RegControl' then
                   switchFound:=True;
                 IF ControlDevice.Enabled THEN ControlDevice.Sample;
                 isClosed:=ControlDevice.Closed[0];
                 ControlDevice := DSSControls.Next;
            End;

          EXCEPT
             On E: Exception DO  Begin
             //DoSimpleMsg(Format('Error Sampling Control Device "%s.%s" %s  Error = %s',[ControlDevice.ParentClass.Name, ControlDevice.Name, CRLF, E.message]), 484);
             //Raise EControlProblem.Create('Solution aborted.');
             End;
          END;
    End;

End;

procedure TFNCS.GetLineSwitchStateForTopics;
var
    elem:TDSSCktElement;
    parentName,thisName,cls,obj,clsobj:string;
    isClosed,switchFound:Boolean;
begin
    IF ActiveCircuit <> Nil THEN
    With ActiveCircuit Do Begin
          elem := Nil;
          switchFound:=false;
          TRY
            // Sample all controls and set action times in control Queue
            elem := CktElements.First;
            WHILE elem <> Nil Do
            Begin
                 //parentName:=elem.ParentClass.Name;
                 //thisName:=elem.Name;
                 cls:=LowerCase(elem.DSSClassName);
                 obj:=LowerCase(elem.LocalName);
                 //clsobj:=elem.DisplayName;
//                 if LineSwitchList.Contains(obj) then
//                   if AllTerminalsClosed(elem) then
//                     topics[cls][obj]['switchstate']['1']['-1']:='1'
//                   else
//                     topics[cls][obj]['switchstate']['1']['-1']:='0';
                 //if parentName<>'RegControl' then
                 //  switchFound:=True;
                 //IF elem.Enabled THEN elem.Sample;
                 //isClosed:=elem.Closed[0];
                 elem := CktElements.Next;
            End;

          EXCEPT
             On E: Exception DO  Begin
             //DoSimpleMsg(Format('Error Sampling Control Device "%s.%s" %s  Error = %s',[ControlDevice.ParentClass.Name, ControlDevice.Name, CRLF, E.message]), 484);
             //Raise EControlProblem.Create('Solution aborted.');
             End;
          END;
    End;
end;
*}

function TFNCS.RoundToSignificantFigure(value:double;digit:Integer):double;
var
  factor:double=1.0;
begin
  RoundToSignificantFigure:=value;
  if value = 0.0 then
    exit;
  factor:=power(10.0,digit-ceil(log10(abs(value))));
  if factor = 0.0 then
    exit;
  RoundToSignificantFigure:=round(value*factor)/factor;
end;

{*
procedure TFNCS.GetVoltageValuesForTopics;
  VAR
     i,j,k:Integer;
     Volts:Complex;
     re:array of double;
     names:TStringList;
     thisBusName,sign,phaseStr:String;
     BusName:string;
     busref,phase:integer;

  Begin
      IF ActiveCircuit <> Nil THEN
       WITH ActiveCircuit DO
       Begin
         setLength(re, 2*NumNodes-1);
         k:=0;
         names:=TStringList.Create;
         FOR i := 1 to NumBuses DO
         Begin
           thisBusName:=Buses^[i].LocalName;
           if topics['bus'].ContainsKey(thisBusName) Then
           begin
             For j := 1 to Buses^[i].NumNodesThisBus DO
             Begin
               //if topics['bus'][thisBusName]['voltage'].ContainsKey(IntToStr(j)) Then
               //begin
                 busref:=Buses^[i].GetRef(j);
                 //nref := pElem.NodeRef^[k];
                 Volts := ActiveCircuit.Solution.NodeV^[busref];//Bus.RefNo saves global numbering of a node in the circuit, the sequence of the numbers in RefNo will be used as local node index
                 phase:=MapNodeToBus^[busref].nodenum;
                 case phase of
                   1:phaseStr:='A';
                   2:phaseStr:='B';
                   3:phaseStr:='C';
                 else
                   phaseStr:=IntToStr(phase);
                 end;
                 if Volts.im < 0 then
                   sign:=''
                 else
                   sign:='+';
                 if topics['bus'][thisBusName]['voltage']['1'].ContainsKey(phaseStr) Then
                   topics['bus'][thisBusName]['voltage']['1'][phaseStr]:=RoundToSignificantFigure(Volts.re,6).ToString+sign+RoundToSignificantFigure(Volts.im,6).ToString+'i';
               //end;
             End;
           end;
         End;
         names.Free;
       End
      ELSE setLength(re, 0);
end;
*}

procedure TFNCS.GetValuesForTopics;
var
  objKey, attKey, trmKey, valKey, dssName: String;
  map: TFNCSMap;
  oad: ObjectAttributeDict;
  atd: AttributeTerminalDict;
  tcd: TerminalConductorDict;
  cvd: ConductorValueDict;
	idxBus, idxPhs, idxLoc, idxNode: Integer;
	Volts: Complex;
	sign: String;
begin
	if topics.containsKey('bus') then begin
		oad := topics.Items['bus'];
		for objKey in oad.Keys do begin
			map := oad.Items[objKey];
			atd := map.atd;
			idxBus := map.idx;
			dssName := ActiveCircuit.BusList.get(idxBus);
			for attKey in atd.Keys do begin
				tcd := atd.Items[attKey];
				for trmKey in tcd.Keys do begin
					cvd := tcd.Items[trmKey];
					for valKey in cvd.Keys do begin
						idxPhs := 1 + Ord(valKey[1]) - Ord('A');
						idxLoc := ActiveCircuit.Buses^[idxBus].FindIdx(idxPhs);
            idxNode := ActiveCircuit.Buses^[idxBus].GetRef(idxLoc);
						Volts := ActiveCircuit.Solution.NodeV^[idxNode];
						if Volts.im < 0 then
							sign:=''
						else
							sign:='+';
						writeln(Format('Bus %s %s %s %s %d %d %d %g %g', 
						  [dssName, attKey, trmKey, valKey, idxPhs, idxLoc, idxNode, Volts.re, Volts.im]));
						cvd[valKey] := RoundToSignificantFigure(Volts.re,6).ToString
						  + sign + RoundToSignificantFigure(Volts.im,6).ToString+'i';
					end;
				end;
			end;
		end;
	end;
end;

procedure TFNCS.DumpFNCSTopics;
var
  clsKey, objKey, attKey, trmKey, valKey: String;
  map:TFNCSMap;
  oad:ObjectAttributeDict;
  atd:AttributeTerminalDict;
  tcd:TerminalConductorDict;
  cvd:ConductorValueDict;
begin
  for clsKey in topics.Keys do begin
    writeln('  ' + clsKey);
    oad := topics.Items[clsKey];
    for objKey in oad.Keys do begin
      writeln('    ' + objKey);
      map := oad.Items[objKey];
      atd := map.atd;
      for attKey in atd.Keys do begin
        writeln('      ' + attKey);
        tcd := atd.Items[attKey];
        for trmKey in tcd.Keys do begin
          writeln('        ' + trmKey);
          cvd := tcd.Items[trmKey];
          for valKey in cvd.Keys do begin
            writeln('          ' + valKey);
          end;
        end;
      end;
    end;
  end;
end;

procedure TFNCS.MapFNCSTopics;
var
  clsKey, objKey, attKey, trmKey, valKey: String;
  map:TFNCSMap;
  oad:ObjectAttributeDict;
  atd:AttributeTerminalDict;
  tcd:TerminalConductorDict;
  cvd:ConductorValueDict;
begin
  FNCSTopicsMapped := True;
  for clsKey in topics.Keys do begin
    oad := topics.Items[clsKey];
    for objKey in oad.Keys do begin
      map := oad.Items[objKey];
      if clsKey = 'bus' then
        map.idx := ActiveCircuit.BusList.Find (objKey)
      else
        map.idx := ActiveCircuit.SetElementActive (clsKey + '.' + objKey);
      if map.idx = 0 then writeln ('*** can not find FNCS output for ' + clsKey + ':' + objKey);
      atd := map.atd;
      for attKey in atd.Keys do begin
        tcd := atd.Items[attKey];
        for trmKey in tcd.Keys do begin
          cvd := tcd.Items[trmKey];
          for valKey in cvd.Keys do begin
          end;
        end;
      end;
    end;
  end;
end;

procedure TFNCS.ReadFncsPubConfig(fname: string);
var
  inputfile:TFileStream;
  parser:TJSONParser;
  config:TJSONData;
  el,attri,cls,obj,terminal,conductor:TJSONEnum;
  attriKey, clsKey, objKey, terminalKey, condKey:string;
  map:TFNCSMap;
  oad:ObjectAttributeDict;
  atd:AttributeTerminalDict;
  tcd:TerminalConductorDict;
  cvd:ConductorValueDict;
  buf: String;
begin
  buf := '   ';
  next_fncs_publish := 0;
  FNCSTopicsMapped := False;
  inputfile:=TFileStream.Create(fname, fmOpenRead);
  fncsOutputStream:=TStringStream.Create(buf);
  try
    parser:=TJSONParser.Create(inputfile, [joUTF8]);
    try
      config:=parser.Parse;
      for el in config do begin
        if el.Key = 'name' then
          FedName:=el.Value.AsString
        else if el.Key = 'publishInterval' then
          PublishInterval:=el.Value.AsInteger
        else if el.Key = 'publishMode' then
          PublishMode:=el.Value.AsString
        else if el.Key = 'topics' then begin
          for cls in el.Value do begin
            clsKey:=LowerCase(cls.Key);
            if topics.ContainsKey(clsKey) then begin
              oad := topics[clsKey];
            end else begin
              oad := ObjectAttributeDict.create([doOwnsValues]);
              topics.AddOrSetValue(clsKey,oad);
            end;
            for obj in cls.Value do begin
              objKey:=LowerCase(obj.Key);
              if oad.ContainsKey(objKey) then begin
                map := oad[objKey];
                atd := map.atd;
              end else begin
                map := TFNCSMap.create();
                atd := map.atd;
                oad.AddOrSetvalue(objKey,map);
              end;
              for attri in obj.Value do begin
                attriKey:=LowerCase(attri.Key);
                if atd.ContainsKey(attriKey) then begin
                  tcd := atd[attriKey];
                end else begin
                  tcd := TerminalConductorDict.Create([doOwnsValues]);
                  atd.AddOrSetvalue(attriKey,tcd);
                end;
                if attri.Value is Tjsonarray then begin
                  terminalKey:='1';
                  if tcd.ContainsKey(terminalKey) then begin
                    cvd := tcd[terminalKey];
                  end else begin
                    cvd := ConductorValueDict.Create;
                    tcd.AddOrSetvalue(terminalKey, cvd);
                  end;
                  if attri.Value.count=0 then cvd.Add('-1', '');
                  for conductor in attri.Value do begin
                    condKey := conductor.Value.asstring;
                    if not cvd.ContainsKey(condKey) then begin
                      cvd.Add(condKey, '');
                    end;
									end;
                end else begin  // attri.Value is not a TJSONArray
                  for terminal in attri.Value do begin
                    terminalKey:=LowerCase(terminal.Key);
                    if tcd.ContainsKey(terminalKey) then begin
                      cvd := tcd[terminalKey];
                    end else begin
                      cvd := ConductorValueDict.Create;
                      tcd.AddOrSetvalue(terminalKey, cvd);
                    end;
                    for conductor in terminal.Value do begin
                      condKey := conductor.Value.asstring;
                      if not cvd.ContainsKey(condKey) then begin
                        cvd.Add(condKey, '');
                      end;
                    end; // terminal.Value
                  end;
                end;  // attri.Value
              end; // attri
            end; // obj
          end; // cls
        end // el.key is topics
        else
          Writeln('*** unknown key "' + el.Key + '" found in FNCS config file.');
      end; // el
    finally
      parser.Free;
    end;
  finally
    inputfile.Free;
  end;
  writeln('Done! This is where we read FNCS publication requests from: ' + fname);
//  DumpFNCSTopics;
end;

procedure TFNCS.TopicsToJsonStream;
var
  attri:TPair<string,TerminalConductorDict>;
  cls:TPair<string,ObjectAttributeDict>;
  map:TPair<string,TFNCSMap>;
  atd:AttributeTerminalDict;
  terminal:TPair<string,ConductorValueDict>;
  conductor:TPair<string,string>;
  firstObjectFlag:Boolean=true;
  writeKeyComma:Boolean=false;
begin
  fncsOutputStream.Seek (0, soFromBeginning);
  fncsOutputStream.WriteString ('{"'+FedName+'":{');
  if topics.Count > 0 then
    for cls in topics do begin
      for map in cls.Value do begin
        atd := map.value.atd;
        if not firstObjectFlag then
          fncsOutputStream.WriteString (',');
        fncsOutputStream.WriteString ('"' + cls.Key+'.'+map.Key + '":{');
        for attri in atd do begin
          for terminal in attri.Value do begin
            for conductor in terminal.Value do begin
              if writeKeyComma then fncsOutputStream.WriteString (',');
              writeKeyComma := True;
              if attri.Value.count > 1 Then
                fncsOutputStream.WriteString ('"'+attri.Key+'.'+terminal.Key+'.'+conductor.Key+'"')
              else if conductor.Key='-1' Then
                fncsOutputStream.WriteString ('"'+attri.Key+'"')
              else
                fncsOutputStream.WriteString ('"'+attri.Key+'.'+conductor.Key+'"');
              fncsOutputStream.WriteString (':"'+conductor.Value+'"');
            end;
          end;
        end;
        fncsOutputStream.WriteString ('}');
        writeKeyComma:=False;
        firstObjectFlag:=False;
      end;
    end;
  fncsOutputStream.WriteString ('}}');
end;

// called from ActiveSolution.Increment_time
function TFNCS.FncsTimeRequest (next_fncs:fncs_time): Boolean;
var
  time_granted: fncs_time;
  events: ppchar;
  key, value: pchar;
  i: integer;
  ilast: size_t;
  nvalues, ival: size_t;
  values: ppchar;
begin
  // execution blocks here, until FNCS permits the time step loop to continue
  time_granted := fncs_time_request (next_fncs);
  if time_granted >= next_fncs_publish then begin
    Writeln(Format('  Stream size %u at %u', [fncsOutputStream.size, time_granted]));
    if Not FNCSTopicsMapped then MapFNCSTopics;
    GetValuesForTopics;
    TopicsToJsonStream;
    fncs_publish ('fncs_output', PChar(fncsOutputStream.DataString));
    next_fncs_publish := next_fncs_publish + PublishInterval;
  end;
  ilast := fncs_get_events_size();
  // TODO: executing OpenDSS commands here may cause unwanted interactions
  if ilast > 0 then begin
    events := fncs_get_events();
    for i := 0 to ilast-1 do begin
      key := events[i];
      nvalues := fncs_get_values_size (key);
      values := fncs_get_values (key);
      for ival := 0 to nvalues-1 do begin
        value := values[ival];
        writeln(Format('  FNCSTimeRequest command %s at %u', [value, time_granted]));
        DSSExecutive.Command := value;
        fncs_publish('fncs_command', value);
      end;
    end;
  end;
  Result := True;
end;

procedure TFNCS.RunFNCSLoop (const s:string);
var
  time_granted, time_stop: fncs_time;
  events: ppchar;
  key, value: pchar;
  i: integer;
  ilast: size_t;
  nvalues, ival: size_t;
  values: ppchar;
begin
  time_granted := 0;
  time_stop := InterpretStopTimeForFNCS(s);
  writeln(Format('Starting FNCS loop to run %s or %u seconds', [s, time_stop]));
  fncs_initialize;

  Try
    while time_granted < time_stop do begin
      time_granted := fncs_time_request (time_stop);
      ilast := fncs_get_events_size();
      if ilast > 0 then begin
        events := fncs_get_events();
        for i := 0 to ilast-1 do begin
          key := events[i];
          nvalues := fncs_get_values_size (key);
          values := fncs_get_values (key);
          for ival := 0 to nvalues-1 do begin
            value := values[ival];
            writeln(Format('FNCS command %s at %u', [value, time_granted]));
            DSSExecutive.Command := value;
            fncs_publish ('fncs_command', value);
          end;
        end;
      end;
    end;
  finally
    fncs_finalize;
  end;
end;

function TFNCS.IsReady:Boolean;
begin
  Result := True;
  if FLibHandle = DynLibs.NilHandle then Result := False;
end;

function TFNCS.find_fncs_function (name: String): Pointer;
begin
  Result := GetProcedureAddress (FLibHandle, name);
  if Result = nil then begin
    writeln ('FNCS library found, but missing function ', name);
    FuncError := True;
  end;
end;

constructor TFNCS.Create;
begin
  FLibHandle := SafeLoadLibrary ('libfncs.' + SharedSuffix);
  topics:=ClassObjectDict.create([doOwnsValues]);
  if FLibHandle <> DynLibs.NilHandle then begin
    FuncError := False;
    @fncs_initialize := find_fncs_function ('fncs_initialize');
    if not FuncError then @fncs_initialize_config := find_fncs_function ('fncs_initialize_config');
    if not FuncError then @fncs_agentRegister := find_fncs_function ('fncs_agentRegister');
    if not FuncError then @fncs_agentRegisterConfig := find_fncs_function ('fncs_agentRegisterConfig');
    if not FuncError then @fncs_is_initialized := find_fncs_function ('fncs_is_initialized');
    if not FuncError then @fncs_time_request := find_fncs_function ('fncs_time_request');
    if not FuncError then @fncs_publish := find_fncs_function ('fncs_publish');
    if not FuncError then @fncs_publish_anon := find_fncs_function ('fncs_publish_anon');
    if not FuncError then @fncs_agentPublish := find_fncs_function ('fncs_agentPublish');
    if not FuncError then @fncs_route := find_fncs_function ('fncs_route');
    if not FuncError then @fncs_die := find_fncs_function ('fncs_die');
    if not FuncError then @fncs_finalize := find_fncs_function ('fncs_finalize');
    if not FuncError then @fncs_update_time_delta := find_fncs_function ('fncs_update_time_delta');
    if not FuncError then @fncs_get_events_size := find_fncs_function ('fncs_get_events_size');
    if not FuncError then @fncs_get_events := find_fncs_function ('fncs_get_events');
    if not FuncError then @fncs_get_event_at := find_fncs_function ('fncs_get_event_at');
    if not FuncError then @fncs_agentGetEvents := find_fncs_function ('fncs_agentGetEvents');
    if not FuncError then @fncs_get_value := find_fncs_function ('fncs_get_value');
    if not FuncError then @fncs_get_values_size := find_fncs_function ('fncs_get_values_size');
    if not FuncError then @fncs_get_values := find_fncs_function ('fncs_get_values');
    if not FuncError then @fncs_get_value_at := find_fncs_function ('fncs_get_value_at');
    if not FuncError then @fncs_get_keys_size := find_fncs_function ('fncs_get_keys_size');
    if not FuncError then @fncs_get_keys := find_fncs_function ('fncs_get_keys');
    if not FuncError then @fncs_get_key_at := find_fncs_function ('fncs_get_key_at');
    if not FuncError then @fncs_get_name := find_fncs_function ('fncs_get_name');
    if not FuncError then @fncs_get_id := find_fncs_function ('fncs_get_id');
    if not FuncError then @fncs_get_simulator_count := find_fncs_function ('fncs_get_simulator_count');
    if not FuncError then @fncs_get_version := find_fncs_function ('fncs_get_version');
    if not FuncError then @fncs_free := find_fncs_function ('_fncs_free');
    if FuncError then begin
      UnloadLibrary(FlibHandle);
      FLibHandle := DynLibs.NilHandle;
    end;
  end;
end;

destructor TFNCS.Destroy;
begin
  topics.free;
  If FLibHandle <> DynLibs.NilHandle Then Begin
    UnloadLibrary(FLibHandle);
  End;
  inherited;
end;

end.

