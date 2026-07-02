B4J=true
Group=Models
ModulesStructureVersion=1
Type=Class
Version=10.5
@EndOfDesignText@
' Crud Model Template
' Customize this template for your database table.
Sub Class_Globals
	Private DB As MiniORM
	
	' Define the database table name
	Private Const TABLE_NAME As String = "tbl_employees"
	
	' Use ModelGenerator
    Type Employees ( _
    employee_name As String, _
    employee_email As String, _
    employee_mobile As String, _
    employee_image() As Byte, _
    employee_salary As Double, _
    department_id As Int, _
    active As Int)
End Sub

Public Sub Initialize
	DB = Main.DB
End Sub

' Retrieve a single row by ID
Public Sub GetRowById (Id As Int) As Map
	DB.Open
	DB.Table = TABLE_NAME
	DB.Columns = Array("id", "employee_email", "employee_name", "employee_salary", "employee_description")
	DB.Condition = "id = ?"
	DB.Parameter = Id
	DB.Query
	If DB.Found Then
		Return DB.First
	End If
	Return CreateMap()
End Sub

' Check if a row exists by ID
Public Sub FindRowById (Id As Int) As Boolean
	DB.Open
	DB.Table = TABLE_NAME
	DB.Find(Id)
	Return DB.Found
End Sub

' Check if a row exists by Email (useful for unique constraints)
Public Sub FindRowByEmail (Email As String) As Boolean
	DB.Open
	DB.Table = TABLE_NAME
	DB.Conditions = Array("employee_email = ?")
	DB.Parameters = Array(Email)
	DB.Query
	Return DB.Found
End Sub

' Check if a row exists by email excluding a specific ID
Public Sub FindRowByEmailNotEqualId (Email As String, Id As Int) As Boolean
	DB.Open
	DB.Table = TABLE_NAME
	DB.Conditions = Array("employee_email = ?", "id <> ?")
	DB.Parameters = Array(Email, Id)
	DB.Query
	Return DB.Found
End Sub

' Search rows by keyword
Public Sub Search (Keyword As String) As List
	DB.Open
	DB.Table = TABLE_NAME
	DB.Columns = Array("id", "employee_email", "employee_name", "employee_salary", "employee_description")
	If Keyword <> "" Then
		DB.Conditions = Array("UPPER(employee_email) LIKE ? Or UPPER(employee_name) LIKE ? Or UPPER(employee_description) LIKE ?")
		DB.Parameters = Array("%" & Keyword.ToUpperCase & "%", "%" & Keyword.ToUpperCase & "%", "%" & Keyword.ToUpperCase & "%")
	End If
	DB.OrderBy = CreateMap("id": "DESC")
	DB.Query
	Return DB.Results
End Sub

Public Sub Found As Boolean
	Return DB.Found
End Sub

Public Sub First As Map
	Return DB.First
End Sub

Public Sub Error As Exception
	Return DB.Error
End Sub

' Insert a new row
Public Sub Create (Email As String, Name As String, Salary As Double, Description As String)
	DB.Open
	DB.Table = TABLE_NAME
	DB.Columns = Array("employee_email", "employee_name", "employee_salary", "employee_description")
	DB.Parameters = Array(Email, Name, Salary, Description)
	DB.ReturnRow = True
	DB.Save
End Sub

' Read all rows
Public Sub Read As List
	DB.Open
	DB.Table = TABLE_NAME
	DB.Columns = Array("id", "employee_email", "employee_name", "employee_salary", "employee_description")
	DB.OrderBy = CreateMap("id": "DESC")
	DB.Query
	Return DB.Results
End Sub

' Update an existing row
Public Sub Update (Id As Int, Email As String, Name As String, Salary As Double, Description As String)
	DB.Open
	DB.Table = TABLE_NAME
	DB.Columns = Array("employee_email", "employee_name", "employee_salary", "employee_description")
	DB.Parameters = Array(Email, Name, Salary, Description)
	DB.Condition = "id = ?"
	DB.Parameter = Id
	DB.ReturnRow = True
	DB.Save
End Sub

' Delete a row by ID
Public Sub Delete (Id As Int)
	DB.Open
	DB.Table = TABLE_NAME
	DB.Id = Id
	DB.Delete
End Sub

Public Sub CreateEmployeesTable
	DB.ShowExtraLogs = True
	DB.UseTimestamps = True
	DB.QueryExecute = False
	DB.QueryAddToBatch = True
	DB.IfNotExist = True
	
	Log("Creating Employees table...")
	DB.Open
	DB.Table = "tbl_employees"
	DB.Columns.Add(CreateMap("Name": "employee_name", "Null": False))
	DB.Columns.Add(CreateMap("Name": "employee_email", "Null": False))
	DB.Columns.Add(CreateMap("Name": "employee_mobile", "Null": True))
	DB.Columns.Add(CreateMap("Name": "employee_description", "Null": False))
	DB.Columns.Add(CreateMap("Name": "employee_image", "Type": DB.BLOB))
	DB.Columns.Add(CreateMap("Name": "employee_salary", "Type": DB.DECIMAL, "Default": "0"))
	DB.Columns.Add(CreateMap("Name": "department_id", "Type": DB.INTEGER, "Default": "0"))
	DB.Columns.Add(CreateMap("Name": "active", "Type": DB.INTEGER, "Default": "0"))
	DB.Create
	
	DB.Columns = Array("employee_name", "employee_email", "employee_description", "employee_salary")
	DB.InsertWithParams = Array("Admin", "admin@admin.com", "Administrator", 69999)
	DB.InsertWithParams = Array("Demo", "demo@demo.com", "Demo", 0)
	
	Wait For (DB.ExecuteBatchAsync) Complete (Success As Boolean)
	If Success Then
		Log("Table Employees created successfully!")
	Else
		Log("Table Employees creation failed!")
	End If
	DB.Close
	DB.QueryExecute = True
End Sub