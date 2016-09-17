//EasyDB
#define CONNECTION_TYPE_MYSQL // tells "easydb" that we are using mysql
#define ENABLE_CONSOLE_MESSAGES // tells "easydb" that we would need console messages/debugs while run time to keep checks and detect if any errors/warnings

//Includes
#include <a_samp>
#include <izcmd>
#include <sscanf2>
#include <easydialog>


//Reg&Logsystem
#define MIN_PASSWORD_LENGTH (5)
#define MAX_PASSWORD_LENGTH (45)

#define MAX_LOGIN_ATTEMPTS (3)

#define PASSWORD_SALT "Di isi 29 char kalo gasalah"

enum E_ACCOUNT
{
	E_ACCOUNT_SQLID,
	E_ACCOUNT_PASSWORD[64],
	E_ACCOUNT_KILLS,
	E_ACCOUNT_DEATHS,
	E_ACCOUNT_MONEY,
	E_ACCOUNT_SCORE
};
new p_Account[MAX_PLAYERS][E_ACCOUNT];

new p_LoginAttempts[MAX_PLAYERS];

public OnGameModeInit()
{
	SetGameModeText("IDC Reborn-BETA");
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
	DB::Init("sa-mp", "localhost", "root", "23tglrejo45");

	// Creating/Verifying table where we'll save user data
	DB::VerifyTable("Users", "ID", false,
						"Name", STRING,
						"Password", STRING,
						"IP", STRING,
						"Kills", INTEGER,
						"Deaths", INTEGER,
						"Money", INTEGER,
						"Score", INTEGER);

	return 1;
}

public OnPlayerConnect(playerid)
{
    p_LoginAttempts[playerid] = 0; // reset login attempts to 0

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	DB::Fetch("Users", _, _, _, "`Name` = '%q'", name);
	if (fetch_rows_count() > 0) //  if the user is existing member (LOGIN)
	{
	    p_Account[playerid][E_ACCOUNT_SQLID] = fetch_row_id();
	    fetch_string("Password", p_Account[playerid][E_ACCOUNT_PASSWORD], 64);
	    p_Account[playerid][E_ACCOUNT_KILLS] = fetch_int("Kills");
	    p_Account[playerid][E_ACCOUNT_DEATHS] = fetch_int("Deaths");
	    p_Account[playerid][E_ACCOUNT_MONEY] = fetch_int("Money");
	    p_Account[playerid][E_ACCOUNT_SCORE] = fetch_int("Score");

	    Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login account...", "{FFFFFF}Good to see you back to SA-MP 0.3.7 Server! Please complete the login formality to access your account (password required).", "Login", "Quit");
	}
	else // user is new (REGISTER)
	{
	    p_Account[playerid][E_ACCOUNT_SQLID] = -1;
	    p_Account[playerid][E_ACCOUNT_PASSWORD][0] = EOS;
	    p_Account[playerid][E_ACCOUNT_KILLS] = 0;
	    p_Account[playerid][E_ACCOUNT_DEATHS] = 0;
	    p_Account[playerid][E_ACCOUNT_MONEY] = 0;
	    p_Account[playerid][E_ACCOUNT_SCORE] = 0;

	    Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register account...", "{FFFFFF}Welcome to SA-MP 0.3.7 Server! Please complete this small registeration formality to sign-up with us (password required).", "Register", "Quit");
	}

	fetcher_close();
	return 1;
}

Dialog:DIALOG_LOGIN(playerid, response, listitem, inputtext[])
{
	// if player clicks "Quit" (will be kicked)
	if (!response)
	    return Kick(playerid);

	// we'll hash player password here which will be further used for comparing
	new password[64];
	SHA256_PassHash(inputtext, PASSWORD_SALT, password, sizeof (password));

	// as we have stored player data when he/she connected, so we'll check the password is matching
	if (strcmp(p_Account[playerid][E_ACCOUNT_PASSWORD], password)) // if password is incorrect
	{
	    p_LoginAttempts[playerid]++;

	    new str[150];
	    format(str, sizeof (str), "Incorrect password, you are left with %i/%i attempts.", p_LoginAttempts[playerid], MAX_LOGIN_ATTEMPTS);
	    SendClientMessage(playerid, 0xFFFFFFFF, str);

	    if (p_LoginAttempts[playerid] >= MAX_LOGIN_ATTEMPTS)
			return Kick(playerid);

	    return Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login account...", "{FFFFFF}Good to see you back to SA-MP 0.3.7 Server! Please complete the login formality to access your account (password required).", "Login", "Quit");
	}

	// player has successfully logged-in
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new str[150];
	format(str, sizeof (str), "Welcome back %s [id: %i]", name, playerid);
 	SendClientMessage(playerid, 0xFFFFFFFF, str);

 	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, p_Account[playerid][E_ACCOUNT_MONEY]);
	SetPlayerScore(playerid, p_Account[playerid][E_ACCOUNT_SCORE]);

 	// update player information
 	new ip[18];
 	GetPlayerIp(playerid, ip, sizeof (ip));

 	DB::Update("Users", p_Account[playerid][E_ACCOUNT_SQLID], 1,
 	                "IP", STRING, ip);

	return 1;
}

Dialog:DIALOG_REGISTER(playerid, response, listitem, inputtext[])
{
	// if player clicks "Quit" (will be kicked)
	if (!response)
	    return Kick(playerid);

	// check if password is not empty
	if (!inputtext[0] || inputtext[0] == ' ')
	{
	    SendClientMessage(playerid, 0xFFFFFFFF, "Invalid password length, cannot be empty.");

	    return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register account...", "{FFFFFF}Welcome to SA-MP 0.3.7 Server! Please complete this small registeration formality to sign-up with us (password required).", "Register", "Quit");
	}

	// check for password lengths
	new len = strlen(inputtext);
	if (len > MAX_PASSWORD_LENGTH || len < MIN_PASSWORD_LENGTH)
	{
	    new str[150];
	    format(str, sizeof (str), "Invalid password length, must be between %i - %i chars.", MIN_PASSWORD_LENGTH, MAX_PASSWORD_LENGTH);
	    SendClientMessage(playerid, 0xFFFFFFFF, str);

	    return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register account...", "{FFFFFF}Welcome to SA-MP 0.3.7 Server! Please complete this small registeration formality to sign-up with us (password required).", "Register", "Quit");
	}

	// hashing the password
	SHA256_PassHash(inputtext, PASSWORD_SALT, p_Account[playerid][E_ACCOUNT_PASSWORD], 64);

	// player has successfully registered
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new str[150];
	format(str, sizeof (str), "Welcome %s [id: %i]", name, playerid);
 	SendClientMessage(playerid, 0xFFFFFFFF, str);

 	// create player's row into "Users" table
 	new ip[18];
 	GetPlayerIp(playerid, ip, sizeof (ip));

 	DB::CreateRow("Users",
 	                "Name", STRING, name,
 	                "Password", STRING, p_Account[playerid][E_ACCOUNT_PASSWORD],
 	                "IP", STRING, ip);

 	DB::Fetch("Users", _, _, _, "`Name` = '%q'", name);
	p_Account[playerid][E_ACCOUNT_SQLID] = fetch_row_id();
 	fetcher_close();

	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    p_Account[playerid][E_ACCOUNT_DEATHS]++; // increase player's deaths count

	if (killerid != INVALID_PLAYER_ID)
    	p_Account[killerid][E_ACCOUNT_KILLS]++; // increase killer's kills count if the id is of a connected player

	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	DB::Update("Users", p_Account[playerid][E_ACCOUNT_SQLID], 1,
 	                "Kills", INTEGER, p_Account[playerid][E_ACCOUNT_KILLS],
 	                "Deaths", INTEGER, p_Account[playerid][E_ACCOUNT_DEATHS],
 	                "Score", INTEGER, GetPlayerScore(playerid),
 	                "Money", INTEGER, GetPlayerMoney(playerid));
	return 1;
}

public OnGameModeExit()
{
	DB::Exit();
	return 1;
}

CMD:changepass(playerid, params[])
{
	new password[64];
	if (sscanf(params, "s[64]", password))
	    return SendClientMessage(playerid, 0xFFFFFFFF, "Usage: /changepass [new password]");

	// check password's length
	new len = strlen(password);
	if (len > MAX_PASSWORD_LENGTH || len < MIN_PASSWORD_LENGTH)
	{
	    new str[150];
	    format(str, sizeof (str), "Invalid password length, must be between %i - %i chars.", MIN_PASSWORD_LENGTH, MAX_PASSWORD_LENGTH);
	    return SendClientMessage(playerid, 0xFFFFFFFF, str);
	}

	// hashing the password
	SHA256_PassHash(password, PASSWORD_SALT, p_Account[playerid][E_ACCOUNT_PASSWORD], 64);

	// update player's password
 	DB::Update("Users", p_Account[playerid][E_ACCOUNT_SQLID], 1,
 	                "Password", STRING, p_Account[playerid][E_ACCOUNT_PASSWORD]);

	return SendClientMessage(playerid, 0xFFFFFFFF, "Password successfully updated.");
}


//Semua dimulai dari 0
