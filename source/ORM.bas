B4J=true
Group=App
ModulesStructureVersion=1
Type=StaticCode
Version=10.5
@EndOfDesignText@
' ORM module
' Version 6.80
Sub Process_Globals
	Private MDB As MiniORM
	Private DBS As MiniORMSettings
	Private Const COLOR_RED  As Int = 0xFFFF0000
	Private Const COLOR_BLUE As Int = 0xFF0000FF
End Sub

Public Sub InitDatabase
	Try
		LogColor("Configuring database...", COLOR_BLUE)
		Dim dbvar As String = "sqlite"
		#If MariaDB
		Dim dbvar As String = "mariadb"
		#End If
		#If MySQL
		Dim dbvar As String = "mysql"
		#End If
		If File.Exists(File.DirApp, $"${dbvar}.ini"$) = False Then
			File.Copy(File.DirAssets, $"${dbvar}.example"$, File.DirApp, $"${dbvar}.ini"$)
		End If
		Dim ctx As Map = File.ReadMap(File.DirApp, $"${dbvar}.ini"$)
		MDB.Initialize
		MDB.ShowExtraLogs = True
		DBS.Initialize
		DBS.DBType = ctx.GetDefault("DbType", "")
		Select DBS.DBType
			Case MDB.MARIADB, MDB.MYSQL
				DBS.DBHost = ctx.GetDefault("DbHost", "")
				DBS.DBPort = ctx.GetDefault("DbPort", "")
				DBS.DBName = ctx.GetDefault("DbName", "")
				DBS.Driver = ctx.GetDefault("DriverClass", "")
				DBS.JdbcUrl = ctx.GetDefault("JdbcUrl", "")
				DBS.User = ctx.GetDefault("User", "")
				DBS.Password = ctx.GetDefault("Password", "")
				DBS.MaxPoolSize = ctx.GetDefault("MaxPoolSize", 0)
			Case MDB.SQLITE
				DBS.DBDir = ctx.GetDefault("DbDir", File.DirApp)
				DBS.DBFile = ctx.GetDefault("DbFile", "Pakai.db")
				DBS.JournalMode = "WAL"
			Case Else
				LogColor($"${DBS.DBType} not supported!"$, COLOR_RED)
				Log("Application is terminated.")
				ExitApplication
		End Select
		MDB.Settings = DBS
		CheckDatabase
	Catch
		LogError(LastException.Message)
		LogColor("Error initialize database!", COLOR_RED)
		Log("Application is terminated.")
		ExitApplication
	End Try
End Sub

Private Sub UsePool (Name As String) As Boolean
	Dim DbArray() As String = Array As String(MDB.MARIADB, MDB.MYSQL)
	Return DbArray.As(List).IndexOf(Name) > -1
End Sub

Private Sub CheckDatabase
	Try
		LogColor("Checking database...", COLOR_BLUE)
		Select MDB.DbType
			Case MDB.SQLITE
				Dim DBExist As Boolean = MDB.Exist
			Case MDB.MARIADB, MDB.MYSQL
				Wait For (MDB.InitSchemaAsync) Complete (Success As Boolean)
				If Success = False Then
					LogColor("Database initilialization failed!", COLOR_RED)
					Log("Application is terminated.")
					ExitApplication
				End If
				If MDB.Test = False Then
					LogColor("Database connection test failed!", COLOR_RED)
					Log("Application is terminated.")
					ExitApplication
				End If
				Wait For (MDB.ExistAsync) Complete (DBExist As Boolean)
			Case Else
				LogColor("Database type is unknown!", COLOR_RED)
				ExitApplication
		End Select
		If DBExist = False Then
			LogColor($"${MDB.DbType} database not existed!"$, COLOR_RED)
			CreateDatabase
			Return
		End If
		LogColor($"${MDB.DbType} database existed!"$, COLOR_BLUE)
		If UsePool(MDB.DbType) Then
			MDB.InitPool
		End If
		
		Main.DB = MDB
		
		' Create new tables after database has already created
		MDB.ShowExtraLogs = False ' shut up log
		MDB.Open
		If MDB.TableExists("tbl_items") = False Then
			Dim Model1 As CrudModel
			Model1.Initialize
			Model1.CreateItemsTable
		End If
		If MDB.TableExists("tbl_users") = False Then
			Dim Model2 As UsersModel
			Model2.Initialize
			Model2.CreateUsersTable
		End If
		If MDB.TableExists("tbl_employees") = False Then
			Dim Model3 As EmployeeModel
			Model3.Initialize
			Model3.CreateEmployeesTable
		End If
		MDB.ShowExtraLogs = True
	Catch
		LogError(LastException.Message)
		LogColor("Error checking database!", COLOR_RED)
		Log("Application is terminated.")
		ExitApplication
	End Try
End Sub

' Create Database Tables and Populate Data
Private Sub CreateDatabase
	LogColor("Creating database...", COLOR_BLUE)
	If UsePool(MDB.DbType) Then
		Wait For (MDB.CreateDatabaseAsync) Complete (Success As Boolean)
	Else
		Dim Success As Boolean = MDB.CreateSQLite
	End If
	If Not(Success) Then
		LogColor("Database creation failed!", COLOR_RED)
		Return
	End If
	
	LogColor("Creating tables...", COLOR_BLUE)
	If UsePool(MDB.DbType) Then
		MDB.InitPool
	End If
	
	MDB.UseTimestamps = True
	MDB.QueryExecute = False
	MDB.QueryAddToBatch = True
	
	MDB.Table = "tbl_items"
	MDB.Columns.Add(CreateMap("Name": "item_code", "Length": "12", "Null": False))
	MDB.Columns.Add(CreateMap("Name": "item_name", "Null": False))
	MDB.Columns.Add(CreateMap("Name": "item_price", "Type": MDB.DECIMAL, "Length": "10,2", "Null": False, "Default": "0.00"))
	MDB.Columns.Add(CreateMap("Name": "item_description", "Null": True))
	MDB.Create
	
	MDB.Columns = Array("item_code", "item_name", "item_price", "item_description")
	MDB.InsertWithParams = Array("ITM001", "Coffee Mug", 12.99, "A ceramic coffee mug.")
	MDB.InsertWithParams = Array("ITM002", "Wireless Mouse", 29.95, "Ergonomic 2.4GHz wireless mouse.")
	MDB.InsertWithParams = Array("ITM003", "Notebook", 4.50, "A5 ruled hardcover journal.")
	
	Wait For (MDB.ExecuteBatchAsync) Complete (Success As Boolean)
	If Success Then
		LogColor("Database is created successfully!", COLOR_BLUE)
	Else
		LogColor("Database creation failed!", COLOR_RED)
	End If
	MDB.Close
	MDB.QueryExecute = True
	Main.DB = MDB
End Sub
