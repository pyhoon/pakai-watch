B4J=true
Group=Handlers
ModulesStructureVersion=1
Type=Class
Version=10.5
@EndOfDesignText@
' Crud Handler Template
' Handles web routes and HTMX endpoints. Customize the routes and model references.
Sub Class_Globals
	Private App As EndsMeet
	Private Path As String
	Private Method As String
	Private View As EmployeeView
	Private Model As EmployeeModel
	Private Request As ServletRequest
	Private Response As ServletResponse
	
	' Customize route endpoints
	Private Const ROUTE_PREFIX As String = "/hx/employees"
End Sub

Public Sub Initialize
	App = Main.App
	View.Initialize
	Model.Initialize
End Sub

Sub Handle (req As ServletRequest, resp As ServletResponse)
	Request = req
	Response = resp
	Path = Request.RequestURI
	Method = Request.Method.ToUpperCase
	Log($"${Method}: ${Path}"$)
	
	' Route URL dispatching
	If Path = "/employees" Then
		HandlePage
	Else If Path = ROUTE_PREFIX & "/table" Then
		HandleTable
	Else If Path = ROUTE_PREFIX & "/add" Then
		HandleModalAdd
	Else If Path.StartsWith(ROUTE_PREFIX & "/edit/") Then
		HandleModalEdit
	Else If Path.StartsWith(ROUTE_PREFIX & "/delete/") Then
		HandleModalDelete
	Else
		HandleCrudActions
	End If
End Sub

Private Sub HandlePage
	App.WriteHtml2(Response, View.Show, App.ctx)
End Sub

' Returns the list of rows (optionally filtered by keyword search)
Private Sub HandleTable
	Dim keyword As String = Request.GetParameter("keyword")
	Dim Rows As List = Model.Search(keyword)
	App.WriteHtml(Response, View.RenderedTable(Rows))
End Sub

' Show Add Modal
Private Sub HandleModalAdd
	App.WriteHtml(Response, View.Modal("Add", Null))
End Sub

' Show Edit Modal
Private Sub HandleModalEdit
	Try
		Dim id As Int = Path.SubString((ROUTE_PREFIX & "/edit/").Length)
	Catch
		Log(LastException)
		ShowAlert($"Error parsing ID: ${LastException.Message}"$, "danger")
		Return
	End Try
	Dim Data As Map = Model.GetRowById(id)
	If Model.Error.IsInitialized Then
		ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
		Return
	End If
	App.WriteHtml(Response, View.Modal("Edit", Data))
End Sub

' Show Delete Modal
Private Sub HandleModalDelete
	Try
		Dim id As Int = Path.SubString((ROUTE_PREFIX & "/delete/").Length)
	Catch
		Log(LastException)
		ShowAlert($"Error parsing ID: ${LastException.Message}"$, "danger")
		Return
	End Try
	Dim Data As Map = Model.GetRowById(id)
	If Model.Error.IsInitialized Then
		ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
		Return
	End If
	App.WriteHtml(Response, View.Modal("Delete", Data))
End Sub

' Handle Database POST, PUT, and DELETE operations
Private Sub HandleCrudActions
	Select Method
		Case "POST"
			' Create
			Dim email As String = Request.GetParameter("email")
			Dim name As String = Request.GetParameter("name")
			Dim tempsalary As String = Request.GetParameter("salary")
			Dim salary As Double = IIf(tempsalary.Trim = "", 0, tempsalary)
			Dim description As String = Request.GetParameter("description")

			If email = "" Or email.Trim.Length < 2 Then
				ShowAlert("Employee Email must be at least 2 characters long.", "warning")
				Return
			End If
			
			' Check Email uniqueness
			Dim Found As Boolean = Model.FindRowByEmail(email)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			If Found Then
				ShowAlert("Employee Email already exists!", "warning")
				Return
			End If

			' Save record
			Model.Create(email, name, salary, description)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If			
			ShowToast("Employee", "created", "Employee created successfully!", "success")
			
		Case "PUT"
			' Update
			Dim id As Int = Request.GetParameter("id")
			Dim email As String = Request.GetParameter("email")
			Dim name As String = Request.GetParameter("name")
			Dim salary As Double = Request.GetParameter("salary")
			Dim description As String = Request.GetParameter("description")
			
			If email = "" Or email.Trim.Length < 2 Then
				ShowAlert("Employee email must be at least 2 characters long.", "warning")
				Return
			End If
			If name = "" Or name.Trim.Length < 2 Then
				ShowAlert("Employee Name must be at least 2 characters long.", "warning")
				Return
			End If
			
			Dim Found As Boolean = Model.FindRowById(id)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			If Not(Found) Then
				ShowAlert("Employee not found!", "warning")
				Return
			End If
			
			Dim EmailConflict As Boolean = Model.FindRowByEmailNotEqualId(email, id)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			If EmailConflict Then
				ShowAlert("Employee Email already exists on another row!", "warning")
				Return
			End If
			
			' Update record
			Model.Update(id, email, name, salary, description)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			ShowToast("Employee", "updated", "Employee updated successfully!", "info")
			
		Case "DELETE"
			' Delete
			Dim id As Int = Request.GetParameter("id")
			
			Dim Found As Boolean = Model.FindRowById(id)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			If Not(Found) Then
				ShowAlert("Employee not found!", "warning")
				Return
			End If

			' Delete record
			Model.Delete(id)
			If Model.Error.IsInitialized Then
				ShowAlert($"Database error: ${Model.Error.Message}"$, "danger")
				Return
			End If
			ShowToast("Employee", "deleted", "Employee deleted successfully!", "danger")
	End Select
End Sub

Private Sub ShowAlert (Message As String, Status As String)
	Dim info As AlertInfo = Main.CreateAlertInfo(Message, Status)
	App.WriteHtml(Response, View.Alert(info))
End Sub

Private Sub ShowToast (Entity As String, Action As String, Message As String, Status As String)
	Dim data As List = Model.Read
	Dim info As ToastInfo = Main.CreateToastInfo(Entity, Action, Message, Status)
	App.WriteHtml(Response, View.Toast(info, data))
End Sub
