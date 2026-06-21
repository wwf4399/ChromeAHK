;@Ahk2Exe-SetName 谷歌浏览器使用体验增强插件
;@Ahk2Exe-SetDescription 功能：1.右键网页标题可以关闭标签页 2.右键“新建标签页”按钮可直接搜索复制内容、或打开复制的网址 3.右键右上角浏览器关闭按钮，可关闭当前标签页 4.左键单击书签可在新窗口打开
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 王伟锋 <2309680188@qq.com>
;@Ahk2Exe-SetOrigFilename 谷歌浏览器AutoHotKey插件.exe
;@Ahk2Exe-SetMainIcon icon.ico

#Requires AutoHotkey v2.0					; 声明运行环境
#SingleInstance Force						; 单例运行模式（强制覆盖）[运行新脚本时，直接自动替换掉后台已经在运行的旧脚本而不是每次都询问]
#HotIf MouseIsOver("ahk_exe chrome.exe")	; HotIf 控制开关		MouseIsOver 是自定义函数		ahk_exe 代表通过进程名来找软件		chrome.exe 是谷歌的进程名字
#Include "第三方库/Acc.ahk"					; 引入 Descolada 维护的 Acc v2 库
; MsgBox									; 弹窗
; SoundBeep(1000, 100)						; 提示音

; === 开机自启动设置 ===
	StartupLink := A_Startup "\谷歌浏览器AutoHotKey插件.lnk"
	if(!FileExist(StartupLink)){
		FileCreateShortcut(A_ScriptFullPath, StartupLink)
	}
; =====================

~LButton:: {							; 最前面写上 波浪线[~] 表示不拦截右键		不写上表示拦截右键，浏览器收不到右键事件		按下时就出发了，不用等到抬起
	ret := ChromeMouseHandler("left")
	; 错误的话，就不往下执行了
		if(ret==false){
			return
		}
	if(ret.hitTestResult==1){
		; 判断是不是收藏栏
			; 在根目录下的收藏
				if(CheckElementsChain(ret.elementsChain, [
					elem => elem.RoleText == '工具栏' && elem.Name == '书签' && elem.StateText == '只读',
					elem => elem.RoleText == '按下按钮' && elem.Name != '' && elem.Description != '' && elem.StateText == '可设定焦点'
				]) == true){
					; 这样子写，是因为了兼容左键拖拽[移动书签]场景，让用户自己触发左键弹起
						Send("{Ctrl Down}{Shift Down}")
						KeyWait("LButton")                                  ; 等待用户真正释放左键
						Send("{Ctrl Up}{Shift Up}")                         ; 释放修饰键
					return
				}
			; 在文件夹里的收藏[正常情况下模拟ctrl+shift+左键就可以了，但是这里死活无法生效]
				if(CheckElementsChain(ret.elementsChain, [
					elem => elem.RoleText == '菜单栏' && (elem.StateText == '已设定焦点' || elem.StateText == '有弹出菜单'),
					elem => elem.RoleText == '弹出式菜单' && elem.StateText == '有弹出菜单',
					elem => elem.RoleText == '菜单项目' && elem.Name != '' && elem.Description != '' && elem.StateText == '可选择'
				]) == true){
					; 这样子写，是因为了兼容左键拖拽[移动书签]场景，让用户自己触发左键弹起
						Send("{Ctrl Down}{Shift Down}")
						KeyWait("LButton")                                  ; 等待用户真正释放左键
						Send("{Ctrl Up}{Shift Up}")                         ; 释放修饰键
					return
				}
	}
}
~RButton:: {
	ret := ChromeMouseHandler("right")
	; 错误的话，就不往下执行了
		if(ret==false){
			return
		}
	if(ret.hitTestResult == 20){
		; SoundBeep(1200, 100)	; 发出提示音[略高]
		Send("^w")				; 发送 Ctrl + W 关闭当前标签页
	}else if(ret.hitTestResult==1){
		; 判断是不是标题栏
			if(CheckElementsChain(ret.elementsChain, [
				elem => elem.RoleText == '选项卡列表' && elem.StateText == '扩展的可选项',
				elem => elem.RoleText == '选项卡' && (elem.StateText == '可选择' || elem.StateText == '可设定焦点')
			]) == true){
				; SoundBeep(1000, 100)							; 发出提示音
				Click("Right Up")								; 右键抬起
				Click("Middle")									; 鼠标中键
				return
			}
		; 判断是不是新建标签页按钮
			if(CheckElementsChain(ret.elementsChain, [elem => elem.RoleText == '按下按钮' && elem.Name == '新标签页' && elem.Description == '打开新的标签页' && elem.StateText == '可设定焦点']) == true){
				Send("^t")										; ctrl + t 新建标签页
				Sleep(50)										; 延迟 50 毫秒
				Send("^v")										; ctrl + v
				Sleep(50)										; 延迟 50 毫秒
				Send("{Enter}")									; 发送回车键
				return
			}
	}
}
; 检查鼠标当前是否悬停在指定条件的窗口上方
	MouseIsOver(WinTitle){
		; 获取进程名
			MouseGetPos(,,&Win)
		return WinExist(WinTitle . " ahk_id " . Win) ; 拼接成这样子的字符串"ahk_exe chrome.exe ahk_id 0x12345"
	}
; 鼠标点击后的公共验证逻辑
	ChromeMouseHandler(clickType){
		; 获取鼠标的点击相对坐标、窗口句柄、鼠标作用的进程名
			CoordMode "Mouse", "Screen"
			MouseGetPos(&screenX, &screenY, &targetHWND, &processName)
		; 获取 Chrome 窗口的最大化状态[0=窗口化 1=最大化]
			try{
				winState := WinGetMinMax("ahk_id " targetHWND)
			}catch{
				return false
			}
		; 判断是不是谷歌; 上面虽然通过HotIf定义了，但是只要谷歌在前台就会触发，例如 有置顶的窗口、谷歌浏览器窗口化、分屏
			realProcessName := WinGetProcessName("ahk_id " targetHWND)
			if(realProcessName != "chrome.exe"){
				return false
			}
		; 获取点击的区域[鼠标正悬停在 Chrome 的什么功能构件[部件]上]，必须用鼠标的相对定位，绝对定位在浏览器窗口化的时候会失真
			try{
				lParam := (screenX & 0xFFFF) | ((screenY & 0xFFFF) << 16)
				hitTestResult := SendMessage(0x84, 0, lParam, , "ahk_id " targetHWND)
					; 0 = 无处可去。鼠标在屏幕空白处，或在不属于任何窗口的边界、隐形边缘上。
					; 1 = 客户区（Client Area）。即网页内容的显示区域。[标签栏的标题栏部分;网址栏;收藏栏;网页本体[body]]
					; 20 = 关闭按钮
			}catch{
				return false
			}
			; SoundBeep(1000, 100)
		; 获取窗口相较于屏幕的定位
			try{
				WinGetPos(, &winY, , , "ahk_id " targetHWND)
			}catch{
				return false
			}
			; 这里只为了解决一个bug，在最大化时，鼠标移动到屏幕最上方，获取的垂直定位，居然是-12
				if(winState == 1){
					winY := 0
				}
			calculatedY := screenY - winY	; 暂时用不到，以前就是用鼠标的点击位置辅佐判断，现在不需要了。但还是保留着
		; 获取该坐标元素及其所有父级组成的数组
			elementsChain := GetElementFamilyChain(screenX, screenY, 5)
		; 验证是否成功抓取
			if(elementsChain.Length == 0){
				return false
			}
		; 先进行简单的排除，别浪费下面的性能
			; 网页的主题部分
				; 极端工况下，读取RoleText有可能会失败的
				try{
					if(elementsChain[1].RoleText == '分组'){
						return false
					}
				}catch{
					return false
				}
				
		; ===================调试用===================
			if(clickType == 'right'){
				;DebugElementsChain(elementsChain)
			}
		; ============================================
		return {
			hitTestResult: hitTestResult,
			elementsChain: elementsChain
		}
	}
; 根据提供的验证规则，验证多层的层级元素中是否全部符合
	CheckElementsChain(elementsChain, matchFuncArr){
		for index, item in matchFuncArr {
			results := each(elementsChain, item)
			if(results.isValid == true){ ; 验证通过
				; 截取出新的数组，免得浪费性能，重复循环
					newArray := []
					loop results.index {
						newArray.Push(elementsChain[A_Index])
					}
				elementsChain := newArray
			}else{
				return false
			}
		}
		each(elementsChain, matchFunc){
			; matchFunc 会读取元素的属性，读取过程有可能会出错，最好套上 try-catch
			try{
				; log('本轮需要循环' . elementsChain.length . '次')
				for index, elem in elementsChain {
					if(matchFunc(elem) == true){
						return {
							index: index,
							isValid: true
						}
					}
				}
				return {
					isValid: false
				}
			}catch{
				return {
					isValid: false
				}
			}
		}
		return true
	}
; ==============================================================================
; 函数名称：DebugElementsChain
; 功能描述：可视化弹窗打印整个 Acc 元素链条的所有属性，方便精准断点调试
; 参数说明：elementsChain - 你的 Acc 元素链条数组
; ==============================================================================
	DebugElementsChain(elementsChain){
		; 拼接所有元素信息查看链条
			debugText := ""
		for index, elem in elementsChain {
			; 标志一下谁是最底层，谁是老祖宗
				tag := (index == 1) ? "【最底层】" : ((index == elementsChain.Length) ? "【最顶层】" : "【父级】")
			
			debugText .= tag " 层级 " index ":`n"
					  .  "    类型: " elem.RoleText "`n"
					  .  "    名称: " elem.Name "`n"
					  .  "    描述: " elem.Description "`n"
					  .  "    值: " elem.value "`n"
					  .  "    状态文本: " elem.StateText "`n"
					  .  "------------------------------------`n"
		}
		MsgBox(debugText)
	}
; ==============================================================================
; 函数名称：GetElementFamilyChain
; 功能描述：通过屏幕坐标抓取最底层元素，并获取指定层数的父级元素，以数组形式返回
; 参数说明：screenX   - 屏幕 X 坐标
;           screenY   - 屏幕 Y 坐标
;           maxLayers - [可选] 允许获取的最大层数，默认为 1 层
; 返回值：  成功返回包含 AHK 元素对象的 Array 数组；失败返回空数组
;           数组索引 [1] 是最底层的叶子节点，[2] 是直系父级... 
; ==============================================================================
	GetElementFamilyChain(screenX, screenY, maxLayers := 1) {
		familyArray := []
		try {
			; 抓取最底层的 UI 元素对象
				currentElement := Acc.ElementFromPoint(screenX, screenY)
			; 循环向上追溯
				while(currentElement){
					; 将当前元素加入数组
						familyArray.Push(currentElement)
					; 如果已经达到了指定的层数上限，直接跳出循环
						if(familyArray.Length >= maxLayers){
							break
						}
					; 尝试获取下一级父元素
						try{
							currentElement := currentElement.Parent
						}catch{
							; 如果遇到没有权限的层级或已到达桌面顶层，则跳出循环
							break
						}
				}
		}catch{
			return []
		}
		return familyArray
	}
; 日志
	Log(message){
		if(message == true){
			formatted := "true"
		}else if(message == false){
			formatted := "false"
		}else{
			formatted := String(message)
		}
		; 发送到编辑器的控制台
			OutputDebug("[AHK_Log] " formatted "`n")
		; 写入到脚本同目录下的 log.txt
			FileAppend("[" A_Hour ":" A_Min ":" A_Sec "] " formatted "`n", A_ScriptDir "\log.txt", "UTF-8")
	}