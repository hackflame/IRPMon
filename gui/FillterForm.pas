Unit FillterForm;

Interface

Uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Generics.Collections, RequestFilter, RequestListModel, Vcl.ExtCtrls,
  Vcl.ComCtrls;

Type
  EFilterComboboxType = (
    fctType,
    fctColumn,
    fctOperator,
    fctValue,
    fctAction,
    fctMax
  );

  TFilterFrm = Class (TForm)
    UpperPanel: TPanel;
    FilterTypeComboBox: TComboBox;
    FilterColumnComboBox: TComboBox;
    FilterOperatorComboBox: TComboBox;
    NegateCheckBox: TCheckBox;
    FilterValueComboBox: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    HighlightColorColorBox: TColorBox;
    FilterActionComboBox: TComboBox;
    Label5: TLabel;
    Label4: TLabel;
    LowerPanel: TPanel;
    CloseButton: TButton;
    OkButton: TButton;
    FilterListView: TListView;
    AddButton: TButton;
    DeleteButton: TButton;
    Procedure FormCreate(Sender: TObject);
    procedure FilterTypeComboBoxChange(Sender: TObject);
    procedure FilterColumnComboBoxChange(Sender: TObject);
    procedure FilterActionComboBoxChange(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure OkButtonClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FilterListViewData(Sender: TObject; Item: TListItem);
    procedure DeleteButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure FilterListViewAdvancedCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage;
      var DefaultDraw: Boolean);
    procedure FilterListViewDblClick(Sender: TObject);
  Private
    FFilterList : TObjectList<TRequestFilter>;
    FCBs : Array [0..Ord(fctMax)-1] of TComboBox;
    Procedure EnableCombobox(AType:EFilterComboboxType; AEnable:Boolean);
    Procedure RefreshListView;
  end;


Implementation

{$R *.DFM}

Uses
  IRPMonDll, IRPRequest, FastIoRequest, Utils,
  FileObjectNameXxxRequest, XXXDetectedRequests;

Procedure TFilterFrm.FilterActionComboBoxChange(Sender: TObject);
Var
  fa : EFilterAction;
  c : TComboBox;
begin
c := (Sender As TComboBox);
fa := EFilterAction(c.ItemIndex);
HighlightColorColorBox.Visible := (fa = ffaHighlight);
HighlightColorColorBox.Enabled := (fa = ffaHighlight);
end;

Procedure TFilterFrm.FilterColumnComboBoxChange(Sender: TObject);
Var
  I : Integer;
  rt : ERequestType;
  ct : ERequestListModelColumnType;
  c : TComboBox;
  tmp : TRequestFilter;
  ss : TList<UInt64>;
  st : TList<WideString>;
  bm : Boolean;
  ops : RequestFilterOperatorSet;
  op : ERequestFilterOperator;
begin
c := (Sender As TComboBox);
EnableComboBox(fctOperator, c.ItemIndex <> -1);
EnableComboBox(fctValue, c.ItemIndex <> -1);
If FilterOperatorComboBox.Enabled Then
  begin
  rt := ERequestType(FilterTypeComboBox.Items.Objects[FilterTypeComboBox.ItemIndex]);
  ct := ERequestListModelColumnType(FilterColumnComboBox.Items.Objects[FilterColumnComboBox.ItemIndex]);
  FilterValueComboBox.Clear;
  tmp := TRequestFilter.NewInstance(rt);
  If Not tmp.SetCondition(ct, rfoAlwaysTrue, 0) Then
    tmp.SetCondition(ct, rfoAlwaysTrue, '');

  ss := TList<UInt64>.Create;
  st := TList<WideString>.Create;
  If tmp.GetPossibleValues(ss, st, bm) Then
    begin
    FilterValueComboBox.Style := csDropDown;
    For I := 0 To ss.Count - 1 Do
      FilterValueComboBox.AddItem(st[I], Pointer(ss[I]));
    end
  Else FilterValueComboBox.Style := csSimple;

  FilterOperatorComboBox.Clear;
  ops := tmp.SupportedOperators;
  For op In ops Do
    FilterOperatorComboBox.AddItem(RequestFilterOperatorNames[Ord(op)], Pointer(Ord(op)));

  st.Free;
  ss.Free;
  tmp.Free;
  end;
end;

Procedure TFilterFrm.FilterListViewAdvancedCustomDrawItem(
  Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
  Stage: TCustomDrawStage; var DefaultDraw: Boolean);
Var
  f : TRequestFilter;
begin
With FilterListView.Canvas Do
  begin
  f := FFilterList[Item.Index];
  If Item.Selected Then
    begin
    Brush.Color := clHighLight;
    Font.Color := clHighLightText;
    Font.Style := [fsBold];
    end
  Else If f.Action = ffaHighlight Then
    begin
    Brush.Color := f.HighlightColor;
    If (f.HighlightColor >= $800000) Or
       (f.HighlightColor >= $008000) Or
       (f.HighlightColor >= $000080) Then
       Font.Color := ClBlack
    Else Font.Color := ClWhite;
    end;
  end;

DefaultDraw := True;
end;

Procedure TFilterFrm.FilterListViewData(Sender: TObject; Item: TListItem);
Var
  f : TRequestFilter;
begin
With Item  Do
  begin
  f := FFilterList[Index];
  Caption := f.Name;
  SubItems.Add(FilterTypeComboBox.Items[Ord(f.RequestType)]);
  SubItems.Add(f.ColumnName);
  SubItems.Add(RequestFilterOperatorNames[Ord(f.Op)]);
  If f.Negate Then
    SubItems.Add('Yes')
  Else SubItems.Add('No');

  SubItems.Add(f.StringValue);
  SubItems.Add(FilterActionComboBox.Items[Ord(f.Action)]);
  end;
end;

Procedure TFilterFrm.FilterListViewDblClick(Sender: TObject);
Var
  f : TRequestFilter;
  L : TListItem;
begin
L := FilterListView.Selected;
If Assigned(L) Then
  begin

  end;
end;

Procedure TFilterFrm.FilterTypeComboBoxChange(Sender: TObject);
Var
  c : TComboBox;
  dr : TDriverRequest;
  rt : ERequestType;
  ct : ERequestListModelColumnType;
  v : WideString;
begin
c := (Sender As TComboBox);
EnableComboBox(fctColumn, c.ItemIndex <> -1);
If FilterColumnComboBox.Enabled Then
  begin
  dr := Nil;
  rt := ERequestType(c.Items.Objects[c.ItemIndex]);
  Case rt Of
    ertUndefined: dr := TDriverRequest.Create;
    ertIRP: dr := TIRPRequest.Create;
    ertIRPCompletion: dr := TIRPCompleteRequest.Create;
    ertAddDevice: dr := TAddDeviceRequest.Create;
    ertDriverUnload: dr := TDriverUnloadRequest.Create;
    ertFastIo: dr := TFastIoRequest.Create;
    ertStartIo: dr := TStartIoRequest.Create;
    ertDriverDetected: dr := TDriverDetectedRequest.Create;
    ertDeviceDetected: dr := TDeviceDetectedRequest.Create;
    ertFileObjectNameAssigned: dr := TFileObjectNameAssignedRequest.Create;
    ertFileObjectNameDeleted: dr := TFileObjectNameDeletedRequest.Create;
    end;

  FilterColumnComboBox.Clear;
  If Assigned(dr) Then
    begin
    For ct := Low(ERequestListModelColumnType) To High(ERequestListModelColumnType) Do
      begin
      If dr.GetColumnValue(ct, v) Then
        FilterColumnComboBox.AddItem(dr.GetColumnName(ct), Pointer(Ord(ct)));
      end;

    dr.Free;
    end;
  end;
end;

Procedure TFilterFrm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
FFilterList.Free;
end;

Procedure TFilterFrm.FormCreate(Sender: TObject);
Var
  bm : Boolean;
  index : Integer;
  ss : TList<UInt64>;
  ts : TList<WideString>;
  tmp : TRequestFilter;
  I : ERequestType;
begin
FFilterList := TObjectList<TRequestFilter>.Create;
FCBs[Ord(fctType)] := FilterTypeComboBox;
FCBs[Ord(fctColumn)] := FilterColumnComboBox;
FCBs[Ord(fctOperator)] := FilterOperatorComboBox;
FCBs[Ord(fctValue)] := FilterValueComboBox;
FCBs[Ord(fctAction)] := FilterActionComboBox;
EnableComboBox(fctColumn, False);
EnableComboBox(fctOperator, False);
EnableComboBox(fctValue, False);

ss := TList<UInt64>.Create;
ts := TList<WideString>.Create;
tmp := TRequestFilter.NewInstance(ertUndefined);
tmp.SetCondition(rlmctRequestType, rfoAlwaysTrue, 0);
tmp.GetPossibleValues(ss, ts, bm);
tmp.Free;
For I := Low(ERequestType) To High(ERequestType) Do
  begin
  tmp := TRequestFilter.NewInstance(I);
  If Assigned(tmp) Then
    begin
    index := ss.IndexOf(Ord(I));
    FilterTypeComboBox.AddItem(ts[Index], Pointer(ss[Index]));
    tmp.Free;
    end;
  end;

ts.Free;
ss.Free;
end;

Procedure TFilterFrm.OkButtonClick(Sender: TObject);
begin
Close;
end;

Procedure TFilterFrm.AddButtonClick(Sender: TObject);
Var
  I : Integer;
  rt : ERequestType;
  ct : ERequestListModelColumnType;
  op : ERequestFilterOperator;
  f : TRequestFilter;
  v : WideString;
  fa : EFilterAction;
  hc : TColor;
  err : Cardinal;
begin
f := Nil;
Try
  If FilterTypeComboBox.ItemIndex = -1 Then
    begin
    ErrorMessage('Filter type is not selected');
    Exit;
    end;

  If FilterColumnComboBox.ItemIndex = -1 Then
    begin
    ErrorMessage('Filtered column not selected');
    Exit;
    end;

  If FilterOperatorComboBox.ItemIndex = -1 Then
    begin
    ErrorMessage('Filter condition operator not selected');
    Exit;
    end;

  rt := ERequestType(FilterTypeComboBox.Items.Objects[FilterTypeComboBox.ItemIndex]);
  ct := ERequestListModelColumnType(FilterColumnComboBox.Items.Objects[FilterColumnComboBox.ItemIndex]);
  op := ERequestFilterOperator(FilterOperatorComboBox.Items.Objects[FilterOperatorComboBox.ItemIndex]);
  fa := EFilterAction(FilterActionComboBox.ItemIndex);
  hc := HighlightColorColorBox.Selected;
  v := FilterValueComboBox.Text;
  For I := 0 To FilterValueComboBox.Items.Count - 1 Do
    begin
    If (v = FilterValueComboBox.Items[I]) Then
      begin
      v := UIntToStr(UInt64(FilterValueComboBox.Items.Objects[I]));
      Break;
      end;
    end;

  f := TRequestFilter.NewInstance(rt);
  If Not Assigned(f) Then
    Exit;

  f.Name := IntToStr(FilterListView.Items.Count + 1);
  f.ColumnName := FilterColumnComboBox.Items[FilterColumnComboBox.ItemIndex];
  If Not f.SetCondition(ct, op, v) Then
    begin
    ErrorMessage('Unable to set filter condition, bad value of the constant');
    Exit;
    end;

  f.Negate := NegateCheckBox.Checked;
  err := f.SetAction(fa, hc);
  If err <> 0 Then
    begin

    Exit;
    end;

  f.Enabled := True;
  FFilterList.Add(f);
  RefreshListView;
  f := Nil;
Finally
  If Assigned(f) Then
    f.Free;
  end;
end;

Procedure TFilterFrm.CloseButtonClick(Sender: TObject);
begin
Close;
end;

Procedure TFilterFrm.DeleteButtonClick(Sender: TObject);
Var
  L : TListItem;
begin
L := FilterListView.Selected;
If Assigned(L) Then
  begin
  FFilterList.Delete(L.Index);
  RefreshListView;
  end;
end;

Procedure TFilterFrm.EnableCombobox(AType:EFilterComboboxType; AEnable:Boolean);
Var
  c : TComboBox;
begin
c := FCBs[Ord(AType)];
c.Enabled := AEnable;
Case c.Enabled Of
  False : c.Color := clBtnFace;
  True : c.Color := clWindow;
  end;
end;

Procedure TFilterFrm.RefreshListView;
begin
FilterListView.Items.Count := FFilterList.Count;
FilterListView.Invalidate;
end;



End.

