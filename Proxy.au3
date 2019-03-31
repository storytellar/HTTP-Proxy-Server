#include <String.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>

FileDelete("logs.txt")

Global $error403 = 'HTTP/1.1 403 Forbidden' & @CRLF & _
				  'Date: Thu, 28 Mar 2019 13:55:20 GMT' & @CRLF & _
				  'Server: Apache/2' & @CRLF & _
				  'Content-Length: 230' & @CRLF & _
				  'Connection: close' & @CRLF & _
				  'Content-Type: text/html; charset=iso-8859-1' & @CRLF & _
				  '' & @CRLF & _
				  '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">' & @CRLF & _
				  '<html><head>' & @CRLF & _
				  '<title>403 Forbidden</title>' & @CRLF & _
				  '</head><body>' & @CRLF & _
				  '<h1>Forbidden (Proxy blocked)</h1>' & @CRLF & _
				  "<p>You don't have permission to access /on this server.</p>" & @CRLF & _
				  '</body></html>'
Global $success = 'HTTP/1.1 400 Bad Request' & @CRLF & _
				  'Date: Thu, 28 Mar 2019 13:55:20 GMT' & _
				  'Server: Apache/2' & @CRLF & _
				  'Content-Length: 192' & @CRLF & _
				  'Connection: close' & @CRLF & _
				  'Content-Type: text/html; charset=iso-8859-1' & @CRLF & _
				  '' & @CRLF & _
				  '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">' & @CRLF & _
				  '<html><head>' & @CRLF & _
				  '<title>Success</title>' & @CRLF & _
				  '</head><body>' & @CRLF & _
				  '<h1>OK !</h1>' & @CRLF & _
				  '<p>This website is NOT in the blacklist</p>' & @CRLF & _
				  '</body></html>'

HotKeySet("{ESC}", "Terminate")
MsgBox(0,"PROXY","Proxy server is ON: 127.0.0.1:8888"& @CRLF &"EXIT: [ESC]")


TCPStartup ()
$TCPListen = TCPListen("127.0.0.1",8888)

Global $count = 0
While(1)
	$count +=1
	; wait connection
	Do
		$iSocket = TCPAccept($TCPListen)
	Until $iSocket <> -1
	FileWriteLine("logs.txt",$count&"- Connected: " & $iSocket)

	; wait message
	Do
		$TCPReceiver = TCPRecv($iSocket,4096)
	Until $TCPReceiver <> ""
	FileWriteLine("logs.txt",$count&"- Message: " & @CRLF & $TCPReceiver)

	; Check if not POST / GET => Close
	If (Not(StringInStr($TCPReceiver, "GET ") <> 0 OR StringInStr($TCPReceiver, "POST ") <> 0)) Then
		TCPCloseSocket($iSocket)
		ContinueLoop
	EndIf

	; Check if Blacklist => Block & Close
	If (isBlacklistRequest($TCPReceiver)) Then
		TCPSend($iSocket,$error403)
		TCPCloseSocket($iSocket)
		ContinueLoop
	EndIf

	$res = getResFromServer($TCPReceiver)
	TCPSend($iSocket,$res)
	FileWriteLine("logs.txt",$count&"- Reply: " & @CRLF & $res)
	TCPCloseSocket($iSocket)

WEnd




Func Terminate()
	TCPShutdown()
    Exit
EndFunc



Func isBlacklistRequest($request)
	$website = getHost($request)
	If (isWebsiteInBacklist($website)) Then
		Return True
	EndIf

	Return False
EndFunc



Func isWebsiteInBacklist($website)
	$website = StringReplace($website,"www.","")

	$data = getDataFromFile("blacklist.conf")

	If (StringInStr($data,$website)) Then
		Return True
	EndIf

	Return False
EndFunc



Func getDataFromFile($fileName)
	Local $hFileOpen = FileOpen($fileName, $FO_READ)
    If $hFileOpen = -1 Then
        ConsoleWrite("Loi: KHONG THE DOC FILE "&$fileName)
		Return False
    EndIf
    $data = FileRead($hFileOpen)
    FileClose($hFileOpen)

	Return $data
EndFunc



Func getResFromServer($request)
	$IP = TCPNameToIP(getHost($request))

	Opt("TCPTimeout", 1000)
    Local $nMaxTimeout = 10 ; script will abort if no server available after 10 secondes

    Local $iError

    While 1

        $iSocket2 = TCPConnect($IP, 80)

        If @error = 10060 Then
            $nMaxTimeout -= 1
            ContinueLoop
        ElseIf @error Then
            $iError = @error
            return $error403 ; temporary, this site is not exist
        Else
           ; success
            ExitLoop
        EndIf

    WEnd



	TCPSend($iSocket2,StringToBinary($request))

	$dataReceive = ""
	Do
		$TCPReceiverX = TCPRecv($iSocket2,4096,1)
		$dataReceive = $dataReceive & $TCPReceiverX
	Until $TCPReceiverX == ""
	$dataReceive= "0x" & StringReplace($dataReceive,"0x","")
	TCPCloseSocket($iSocket2)

	return $dataReceive

EndFunc



Func getHost($request)
	$website = _StringBetween($request, ": ", "User-Agent:")[0]
	$website = StringReplace ($website, @CRLF, "")
	Return $website
EndFunc


