#include "Json.au3"


#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#Region ### START Koda GUI section ### Form=
Global $form_main = GUICreate("Form1", 809, 517, -1, -1)
GUISetFont(20, 400, 0, "Segoe UI")
Global $label_file_path = GUICtrlCreateLabel("duong dan token", 24, 24, 208, 41)
Global $input_file_path = GUICtrlCreateInput("", 256, 24, 393, 45)
Global $button_browse_file_path = GUICtrlCreateButton("Button1", 672, 24, 123, 49)
Global $label_content_reply = GUICtrlCreateLabel("noi dung tra loi", 24, 112, 187, 41)
Global $input_content_reply = GUICtrlCreateInput("", 256, 112, 393, 45)
Global $checkbox_save_phone = GUICtrlCreateCheckbox("luu so dien thoai trong binh luan", 256, 192, 457, 41)
Global $checkbox_hide_comment = GUICtrlCreateCheckbox("an binh luan", 256, 264, 313, 41)
Global $label_delay_time = GUICtrlCreateLabel("do tre  hanh dong", 24, 336, 218, 41)
Global $input_delay_time = GUICtrlCreateInput("1000", 256, 336, 113, 45, BitOR($GUI_SS_DEFAULT_INPUT,$ES_CENTER,$ES_NUMBER))
Global $button_start = GUICtrlCreateButton("Bat dau", 256, 424, 171, 57)
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
			MsgBox(16+262144, "Lỗi", "Không đọc được token")
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
	local $delay_time = GUICtrlRead($input_delay_time)
	local $file_path_phone_numbers = FileOpen('phones.txt', 1)

	for $comment in $comments
		local $comment_id = json_get($comment, '["id"]')
		local $comment_message = json_get($comment, '["message"]')

		;Kiểm tra nếu có nội dung thì auto bình luận
		if $content_comments Then
			_auto_reply($comment_id, $content_comments)
		EndIf

		;kiểm tra nếu có tick vào checkbox lưu số điện thoại
		if $save_phone == $GUI_CHECKED Then
			_extract_phone_number($comment_message, $file_path_phone_numbers)
		EndIf

		;kiểm tra nếu có tick vào checkbox ẩn bình luận
		if $hide_comment = $GUI_CHECKED Then
			_hide_comment($comment_id)
		EndIf

	Next
	
	FileClose($file_path_phone_numbers)
	
	;đệ quy, sau một khoảng delay thì tự động gọi lại hàm scan
	Sleep($delay_time)
	scan()
	
EndFunc

Func _hide_comment($comment_id)
	_graph('/' & $comment_id & '?method=post&is_hidden=true')
EndFunc

Func _extract_phone_number($message, $file_path_phone_numbers)
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
	Return $json
EndFunc


