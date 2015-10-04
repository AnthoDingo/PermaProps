
	require('mysqloo')

	local HOST = "localhost"
	local USER = "user"
	local PASS = ""
	local DATABASE = ""
	local PORT = 3306
	
	if !mysqloo then MsgN("[PermaProps] -> Failed to load mysqloo module.\n\tPlease recheck your version to make sure it's installed correctly.\n\tAlso check to see if you have the right version.") return end
	
	Perma.MySQL = mysqloo.connect(HOST, USER, PASS, DATABASE, PORT)
	Perma.MySQL.onConnected = function()
		Perma.MySQLConnected = true
		
		MsgN("[PermaProps] Successfully to connect to database.")
		init()
	end
	Perma.MySQL.onConnectionFailed = function(db, err)
		Perma.MySQLConnected = false
		MsgN("[PermaProps] Failed to connect to database -> " .. err)
	end
	Perma.MySQL:connect()