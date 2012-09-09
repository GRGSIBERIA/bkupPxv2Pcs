=begin
イラスト用クラスのファイル
=end
require 'net/http'
require 'mechanize'



# MechanizeでHTMLのソースコードを取得するクラス
class HTMLSource
	# URLからGETリクエストを送り、ソースコードを取得する
	def initialize(url)
		@agent = Mechanize.new
		@agent.get(url)
	end
end

class IllustNotFoundError < StandardError; end

# イラスト情報を格納するためのクラス
class Illust < HTMLSource
	def initialize(illust_id)
		request = GetRequest.new("illust")		# コンストラクタでイラストを指定
		request.SetParameter("mode", "medium")
		request.SetParameter("illust_id", illust_id)
		
		super(request.GetRequestURL())	# ここでMechanizeの初期化を行う
	
		if !@agent.page.at('span[@class="error"]') then
			raise IllustNotFoundError, illust_id.to_s + " is not found."
		end
	
		@illust_id = illust_id
		@title = GetTitle()
		@caption = GetCaption()
		@tags = GetTags()
		@member_id = GetMemberID()
		@member_name = GetMemberName()
	end
	attr_reader :illust_id
	attr_reader :title
	attr_reader :caption
	attr_reader :tags
	attr_reader :member_name
	attr_reader :member_id
	
	# タイトルを取得してくる
	def GetTitle()
		path = 'h1[@class="title"]'
		return @agent.page.at(path).inner_text
	end
	
	# イラストの記事内容
	def GetCaption()
		path = 'div[@id="caption_long"]'
		return @agent.page.at(path).inner_text
	end
	
	# タグを取得
	def GetTags()
		#path = 'div[@id="tag_area"]'
		path = 'div[@class=pedia]'
		path += '//a'
		
		# 拾ってきたタグの中から関連ページを排除する
		all_tags = @agent.page.search(path)
		tags = Array.new
		for i in 0..all_tags.length-1
			all_tags[i].each{|k,v| 
				if v.include?("tags.php") then # tags.php以外のタグは排除
					tags << all_tags[i].inner_text 
				end
			}
		end
		return tags
	end
	
	# 投稿者のPixivメンバーIDの取得
	def GetMemberID()
		path = 'h2/a'
		link = @agent.page.search(path)
		member_id = ""
		for i in 0..link.length-1
			if link[i]['href'].include?('member.php?') then
				member_id = link[i]['href']
				break
			end
		end
		return member_id.sub!("member.php?id=", "")
	end
	
	# Pixivメンバーの名前を取得する
	def GetMemberName()
		path = 'h2/a/img'
		link = @agent.page.search(path)
		member_name = ""
		for i in 0..link.length-1
			# imgタグの中にtitleというタグがあって、そこにメンバーの名前が格納されている
			if link[i]['title'] != nil then
				member_name = link[i]['title']
				break
			end
		end
		return member_name
	end
end



# GETリクエストを送るクラス
class GetRequest

	# 初期化するのにページの種類を指定する
	# 小文字でillustかmemberのどちらか
	def initialize(page_type)
		@request_url = "www.pixiv.net"
		@page_url = ""
		@param_value_pair = Hash::new
		@set_param_flag = false
		
		# PageTypeの内容からどのページにリクエストを送りたいのか判断する
		case page_type
		when "member"
			@page_url = "/member.php"
		when "illust"
			@page_url = "/member_illust.php"
		end
	end
	
	# GETで送るパラメータと値を指定する
	def SetParameter(parameter, value)
		if @set_param_flag == false then
			@page_url += "?"
			@set_param_flag = true
		else
			@page_url += "&" 
		end
		@page_url += parameter.to_s +  "=" + value.to_s
	end
	
	# GETでリクエストを送信し、その結果を取得する
	def SendRequest()	
		# URLを展開してGETでアクセス、responseに結果を入れる
		request = Net::HTTP::Get.new(@page_url)
		response = Net::HTTP.start(@request_url, 80) {|http|
			http.request(request)
		}
		return response.body	# 本文のみを返す
	end
	
	# リクエストを送るURLを展開する
	def GetRequestURL()
		return "http://" + @request_url + @page_url
	end
end


