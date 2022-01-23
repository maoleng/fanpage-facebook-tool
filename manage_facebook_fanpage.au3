#include "Json.au3"
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#Region ### START Koda GUI section ### Form=
Global $form_main = GUICreate("Manage Fanpage Facebook Tool", 809, 450, -1, -1)
GUISetFont(20, 400, 0, "Segoe UI")
Global $label_file_path = GUICtrlCreateLabel("Đường dẫn token", 24, 24, 208, 41)
Global $input_file_path = GUICtrlCreateInput("", 256, 24, 393, 45)
Global $button_browse_file_path = GUICtrlCreateButton("Open", 672, 24, 123, 49)
Global $label_content_reply = GUICtrlCreateLabel("Nội dung trả lời", 24, 112, 187, 41)
Global $input_content_reply = GUICtrlCreateInput("", 256, 112, 393, 45)
Global $checkbox_save_phone = GUICtrlCreateCheckbox("Lưu số điện thoại trong bình luận", 256, 192, 457, 41)
Global $checkbox_hide_comment = GUICtrlCreateCheckbox("Ẩn bình luận", 256, 264, 313, 41)
Global $button_start = GUICtrlCreateButton("Bắt đầu", 256, 350, 171, 57)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

Global $access_token = NUll

While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			Exit

		Case $button_browse_file_path
			$access_token = _load_access_token()
		Case $button_start
			_start()
	EndSwitch
WEnd


Func _load_access_token ()
	local $file_path = FileOpenDialog("Open", @ScriptDir, "Text (*.ini)", 1 + 2, "", $form_main)

	if $file_path Then
		local $access_token = IniRead($file_path, 'facebook', 'token', '')
		If Not $access_token Then
			MsgBox(16+262144, "Lỗi", "Vui lòng kiểm tra lại token")
		EndIf
	EndIf

	GUICtrlSetData($input_file_path, $file_path)
	Return $access_token
EndFunc

Func _start()
	If Not $access_token Then
		MsgBox(16 + 262144, "Lỗi", "Vui lòng kiểm tra lại token")
		Return
	EndIf
	scan()
EndFunc

Func scan()

	;lấy ra id bài viết mới nhất
	Local $json = _graph('/me/feed?limit=1')
	Local $post_id = json_get($json, '["data"][0]["id"]')

	;lấy ra các bình luận trong bài viết đó
	$json = _graph('/' & $post_id & '/' & 'comments')

	local $comments = json_get($json, '["data"]')
	local $content_comments = GUICtrlRead($input_content_reply)
	local $save_phone = GUICtrlRead($checkbox_save_phone)
	local $hide_comment = GUICtrlRead($checkbox_hide_comment)
	local $file_path_phone_numbers = FileOpen('phones.txt', 1)

	for $comment in $comments
		local $comment_id = json_get($comment, '["id"]')
		local $comment_message = json_get($comment, '["message"]')

		;kiểm tra nếu có tick vào checkbox lưu số điện thoại
		if $save_phone == $GUI_CHECKED Then
			local $phone_numbers = StringRegExp($comment_message, '0[0-9]{9,10}', 3)
			if @error Then
				ContinueLoop
			EndIf
			For $phone_number in $phone_numbers
				FileWriteLine($file_path_phone_numbers, $phone_number)
			Next
		EndIf

		;Kiểm tra nếu có nội dung thì auto bình luận
		if $content_comments Then
			_auto_reply($comment_id, $content_comments)
		EndIf

		;kiểm tra nếu có tick vào checkbox ẩn bình luận
		if $hide_comment = $GUI_CHECKED Then
			_hide_comment($comment_id)
		EndIf

	Next

	FileClose($file_path_phone_numbers)

	MsgBox(16+262144, "Thông báo", "Thành công")
EndFunc

Func _hide_comment($comment_id)
	_graph('/' & $comment_id & '?method=post&is_hidden=true')
EndFunc

Func _extract_phone_number($message, $file_path_phone_numbers, $check_error)
	local $phone_numbers = StringRegExp($message, '0[0-9]{9,10}', 3)
	For $phone_number in $phone_numbers
		FileWriteLine($file_path_phone_numbers, $phone_number)
	Next

EndFunc

Func _auto_reply($comment_id, $content_comments)
	Return _graph('/' & $comment_id & '/comments?method=post&message=' & $content_comments)
EndFunc


Func _graph($path)
	local $url = 'https://graph.facebook.com'

	$url &= $path

	if StringInStr($url, "?") Then
		$url &= '&'
	Else
		$url &= '?'
	EndIf

	$url &= 'access_token=' & $access_token

	Local $oHTTP = ObjCreate('WinHttp.WinHttpRequest.5.1')
	$oHTTP.open('GET', $url, False)
	$oHTTP.SetRequestHeader("user-agent", "PostmanRuntime/7.28.4")
	$oHTTP.send()
	$oHTTP.WaitForResponse

	$response_text = $oHTTP.responseText
	$json = json_decode($response_text)
	$error_message = json_get($json, '["error"]["message"]')
	if $error_message == "The access token could not be decrypted" Then
		MsgBox(16+262144, "Lỗi", "Kiểm tra lại token đi")
		Exit
	EndIf

	Return $json
EndFunc
