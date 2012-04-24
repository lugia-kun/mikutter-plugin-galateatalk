# -*- coding: utf-8; mode: ruby; -*-

require 'nkf'

Plugin.create :galatea_talk do
  gtalk_bin = ''
  conf_file = ''
  speaker = ''
  msgs = []

  if UserConfig[:gtalk_conf] != nil then
    conf_file = UserConfig[:gtalk_conf]
  end
  if conf_file != '' then
    fi = open(conf_file, "r")
    sids = fi.readlines
    fi.close
    sids.reject! do |m|
      m !~ /SPEAKER-ID: /
    end
    sidp = {}
    sids.each do |m|
      n = m.gsub(/^SPEAKER-ID: *(.*)\n$/, "\\1")
      sidp["#{n}"] = "#{n}"
    end
  else
    sidp = {}
  end

  settings("Galatea Talk") do
    settings("Galatea Talk") do
      fileselect("Gtalk バイナリ (gtalk)", :gtalk_bin)
      fileselect("Gtalk 設定ファイル (ssm.conf)", :gtalk_conf)
    end

    settings("SSM 設定") do
      select("デフォルトの話者", :gtalk_speaker, sidp)
    end

    multi("開始時メッセージ", :gtalk_messages)
    about("about",
          {
            :name => "mikutter + Galatea talk plugin",
            :version => "1.0",
            :comments => "反映には再起動が必要です",
            :copyright => "Copyright (C) 2012 Hajime Yoshimori",
            :authors => ["@LugiaKun"]
          })
  end

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

  @cpid = -1
  @rd, @wr = IO.pipe

  onboot do
    if UserConfig[:gtalk_bin] != nil then
      gtalk_bin = UserConfig[:gtalk_bin]
    end
    if UserConfig[:gtalk_conf] != nil then
      conf_file = UserConfig[:gtalk_conf]
    end
    if UserConfig[:gtalk_speaker] != nil then
      speaker = UserConfig[:gtalk_speaker]
    end
    if UserConfig[:gtalk_messages] != nil then
      msgs = UserConfig[:gtalk_messages]
    end

    if gtalk_bin == '' || conf_file == '' then
      break
    end

    @cpid = fork {
      @wr.close
      gtalk = IO.popen("#{gtalk_bin} -C #{conf_file}", "r+") || raise
      wait_for_msg(gtalk, "rep Run = LIVE\n") || raise
      if speaker != '' then
        gtalk.puts "set Speaker = #{speaker}\n"
        wait_for_msg(gtalk, "rep Speaker = #{speaker}\n") || raise
      end
      while msg = @rd.gets do
        gtalk.puts NKF.nkf("-We", "set Text = #{msg}\n")
        wait_for_msg(gtalk, "rep Speak.stat = READY\n") || raise
        gtalk.puts "set Speak = NOW\n"
        wait_for_msg(gtalk, "rep Speak.stat = IDLE\n") || raise
      end
      @rd.close
      gtalk.puts "set Run = EXIT\n"
      gtalk.close
      exit
    }
    @rd.close

    msgs.each do |msg|
      nmsg = msg.gsub(/\n/, " ")
      @wr.puts nmsg
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
      @wr.puts nmsg
    end
  end

  oldmsgf = ""
  onfavorite do |serv,user,msg|
    if oldmsgf != msg.body then
      nmsg = msg.body.gsub(/\n/, " ")
    else
      nmsg = "同じの"
    end
    @wr.puts user[:name] + "が「<EMPH>" + nmsg + "</EMPH>」をファボッたよ。"
    oldmsgf = msg.body
  end

#  oldmsgr = ""
#  onretweet do |msgs|
#    msgs.each do |msg|
#      puts msg.body
#      if oldmsgr != msg.body then
#        nmsg = msg.body.gsub(/\n/, " ")
#      else
#        nmsg = "同じの"
#      end
#      @wr.puts "「<EMPH>" + nmsg + "</EMPH>」を<SPELL>RT</SPELL>したよ。"
#      oldmsgr = msg.body
#    end
#  end

  at_exit do
    @wr.close
    wait @cpid
  end
end
