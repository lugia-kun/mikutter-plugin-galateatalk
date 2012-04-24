# -*- coding: utf-8; mode: ruby; -*-

require 'nkf'

Plugin.create :galatea_talk do
  gtalk_bin = '/home/lugia/galatea-v3.0/SSM/gtalk'
  conf_file = '../plugin/ssm.conf'
  speaker = 'female01'
  msgs = ["本日は晴天なり。発話者は #{speaker} です。"]

  def wait_for_msg (stream, msg)
    while 1 do
      rep = stream.gets
      if rep == nil then
        return 1
      end
      puts NKF.nkf("-Ew", rep)
      if rep == msg then
        break
      end
    end
    return 0
  end

  rd, wr = IO.pipe
  cpid = fork {
    wr.close
    gtalk = IO.popen("#{gtalk_bin} -C #{conf_file}", "r+") || raise
    wait_for_msg(gtalk, "rep Run = LIVE\n") || raise
    gtalk.puts "set Speaker = #{speaker}\n"
    wait_for_msg(gtalk, "rep Speaker = #{speaker}\n") || raise
    while msg = rd.gets do
      gtalk.puts NKF.nkf("-We", "set Text = #{msg}\n")
      wait_for_msg(gtalk, "rep Speak.stat = READY\n") || raise
      gtalk.puts "set Speak = NOW\n"
      wait_for_msg(gtalk, "rep Speak.stat = IDLE\n") || raise
    end
    rd.close
    gtalk.puts "set Run = EXIT\n"
    gtalk.close
    exit
  }
  rd.close

  onboot do
    msgs.each do |msg|
      nmsg = msg.gsub(/\n/, " ")
      wr.puts nmsg
    end
  end

  idname = "00000000"
  onmention do |serv,msgs|
    msgs.each do |msg|
      nmsg = msg.body
      if serv != nil then
        nmsg = nmsg.gsub(/@#{serv.idname.to_s}/i, "")
        idname = serv.idname
      else
        nmsg = nmsg.gsub(/@#{idname}/i, "")
      end
      nmsg = nmsg.gsub(/\n/, " ")
      wr.puts nmsg
    end
  end

  oldmsg = ""
  onfavorite do |serv,user,msg|
    if oldmsg == msg.body then
      nmsg = msg.body.gsub(/\n/, " ")
    else
      nmsg = "同じの"
    end
    wr.puts user[:name] + "が「<EMPH>" + nmsg + "</EMPH>」をファボったよ。"
    oldmsg = msg.body
  end

  at_exit do
    wr.close
    wait cpid
  end
end

