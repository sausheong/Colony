%w(dm-core dm-timestamps dm-validations dm-aggregates).each {|lib| gem lib, '=0.9.11'}
%w(dm-core dm-timestamps dm-validations dm-aggregates RMagick right_aws config).each  { |lib| require lib}
include Magick
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:root@localhost/faceclone')
S3 = RightAws::S3Interface.new(S3_CONFIG['AWS_ACCESS_KEY'], S3_CONFIG['AWS_SECRET_KEY'], {:multi_thread => true, :protocol => 'http', :port => 80} )

module Commentable 
  def people_who_likes
    self.likes.collect { |l| "<a href='/user/#{l.user.nickname}'>#{l.user.formatted_name}</a>"  }
  end  
end

class User
  include DataMapper::Resource

  property :id,         Serial
  property :email,      String, :length => 255
  property :nickname,   String, :length => 255
  property :formatted_name, String, :length => 255
  property :sex, String, :length => 6
  property :relationship_status, String
  property :provider,   String, :length => 255
  property :identifier, String, :length => 255
  property :photo_url,  String, :length => 255
  property :location, String, :length => 255
  property :description, String, :length => 255
  property :interests, Text
  property :education, Text
  has n, :relationships
  has n, :followers, :through => :relationships, :class_name => 'User', :child_key => [:user_id]
  has n, :follows, :through => :relationships, :class_name => 'User', :remote_name => :user, :child_key => [:follower_id]
  has n, :statuses
  belongs_to :wall
  has n, :groups, :through => Resource
  has n, :sent_messages, :class_name => 'Message', :child_key => [:user_id]
  has n, :received_messages, :class_name => 'Message', :child_key => [:recipient_id]
  has n, :confirms
  has n, :confirmed_events, :through => :confirms, :class_name => 'Event', :child_key => [:user_id], :date.gte => Date.today 
  has n, :pendings
  has n, :pending_events, :through => :pendings, :class_name => 'Event', :child_key => [:user_id], :date.gte => Date.today 
  has n, :requests
  has n, :albums
  has n, :photos, :through => :albums
  has n, :comments
  has n, :activities
  has n, :pages
      
  validates_is_unique :nickname, :message => "Someone else has taken up this nickname, try something else!"
  after :create, :create_s3_bucket
  after :create, :create_wall
  
  def add_friend(user)
    Relationship.create(:user => user, :follower => self)  
  end
  
  def pending_friends
    followers - follows
  end
  
  def friends
    (followers + follows).uniq
  end         
  
  def self.find(identifier)
    u = first(:identifier => identifier)
    u = new(:identifier => identifier) if u.nil?
    return u
  end  

  def feed
    feed = [] + activities
    friends.each do |friend|
      feed += friend.activities
    end
    return feed.sort {|x,y| y.created_at <=> x.created_at}
  end

  def possessive_pronoun
    sex.downcase == 'male' ? 'his' : 'her'
  end
  
  def pronoun
    sex.downcase == 'male' ? 'he' : 'she'
  end

  def create_s3_bucket
    S3.create_bucket("fc.#{id}")
  end
  
  def create_wall
    self.wall = Wall.create
    self.save
  end

  def all_events
    confirmed_events + pending_events
  end

  def friend_events
    events = []
    friends.each do |friend|
      events += friend.confirmed_events
    end
    return events.sort {|x,y| y.time <=> x.time}    
  end
  
  def friend_groups
    groups = []
    friends.each do |friend|
      groups += friend.groups
    end
    groups
  end

end

class Relationship
  include DataMapper::Resource

  property :user_id, Integer, :key => true
  property :follower_id, Integer, :key => true
  belongs_to :user, :child_key => [:user_id]
  belongs_to :follower, :class_name => 'User', :child_key => [:follower_id]
  after :save, :add_activity
  
  def add_activity
    Activity.create(:user => user, :activity_type => 'relationship', :text => "<a href='/user/#{user.nickname}'>#{user.formatted_name}</a> and <a href='/user/#{follower.nickname}'>#{follower.formatted_name}</a> are now friends.")    
  end  
end

class Mention
  include DataMapper::Resource
  property :id,         Serial
  belongs_to :user
  belongs_to :status
end

URL_REGEXP = Regexp.new('\b ((https?|telnet|gopher|file|wais|ftp) : [\w/#~:.?+=&%@!\-] +?) (?=[.:?\-] * (?: [^\w/#~:.?+=&%@!\-]| $ ))', Regexp::EXTENDED)
AT_REGEXP = Regexp.new('@[\w.@_-]+', Regexp::EXTENDED)

class Message
  include DataMapper::Resource
  property :id, Serial
  property :subject, String
  property :text, Text
  property :created_at,  DateTime  
  property :read, Boolean, :default => false
  property :thread, Integer
  
  belongs_to :sender, :class_name => 'User', :child_key => [:user_id]
  belongs_to :recipient, :class_name => 'User', :child_key => [:recipient_id]  
end

class Status
  include DataMapper::Resource
  include Commentable
  
  property :id, Serial
  property :text, String, :length => 160
  property :created_at,  DateTime  
  belongs_to :recipient, :class_name => "User", :child_key => [:recipient_id]
  belongs_to :user  
  has n, :mentions
  has n, :mentioned_users, :through => :mentions, :class_name => 'User', :child_key => [:user_id]
  has n, :comments
  has n, :likes
  
  before :save do
    @mentions = []
    process
  end

  after :save do
    unless @mentions.nil?
      @mentions.each {|m|
        m.status = self 
        m.save 
      }
    end
    Activity.create(:user => user, :activity_type => 'status', :text => self.text )
  end

  # general scrubbing 
  def process
    # process url
    urls = self.text.scan(URL_REGEXP)
    urls.each { |url|
      tiny_url = open("http://tinyurl.com/api-create.php?url=#{url[0]}") {|s| s.read}    
      self.text.sub!(url[0], "<a href='#{tiny_url}'>#{tiny_url}</a>")
    }        
    # process @
    ats = self.text.scan(AT_REGEXP)
    ats.each { |at| 
      user = User.first(:nickname => at[1,at.length])
      if user
        self.text.sub!(at, "<a href='/#{user.nickname}'>#{at}</a>") 
        @mentions << Mention.new(:user => user, :status => self)
      end      
    }            
  end

  def starts_with?(prefix)
    prefix = prefix.to_s
    self.text[0, prefix.length] == prefix
  end  
  
  def to_json(*a)
    {'id' => id, 'text' => text, 'created_at' => created_at, 'user' => user.nickname}.to_json(*a)
  end
end

class Activity
  include DataMapper::Resource
  include Commentable     
  
  property :id, Serial
  property :activity_type, String
  property :text, Text
  property :created_at, DateTime
  has n, :comments
  has n, :likes
  belongs_to :user
end

class Photo
  include DataMapper::Resource
  include Commentable
    
  attr_writer :tmpfile
  property :id,         Serial
  property :title,      String, :length => 255
  property :caption,    String, :length => 255
  property :privacy,    String, :default => 'public'
  
  property :format,     String
  property :created_at, DateTime
  
  belongs_to :album

  has n, :annotations
  has n, :comments
  has n, :likes
  
  after :save, :save_image_s3
  after :save, :add_activity
  after :destroy, :destroy_image_s3

  
  def filename_display; "#{id}.disp"; end  
  def filename_thumbnail; "#{id}.thmb"; end
  
  def s3_url_thumbnail; S3.get_link(s3_bucket, filename_thumbnail); end 
  def s3_url_display; S3.get_link(s3_bucket, filename_display); end

  def url_thumbnail
    s3_url_thumbnail   
  end

  def url_display
    s3_url_display
  end  
  
  def previous_in_album 
    photos = album.photos       
    index = photos.index self
    return nil unless index
    photos[index - 1] if index > 0
  end

  def next_in_album
    photos = album.photos
    index = photos.index self
    return nil unless index
    photos[index + 1] if index < album.photos.length 
  end              

  def save_image_s3
    return unless @tmpfile
    p @tmpfile
    p @tmpfile.open
    p Image.read(@tmpfile.open)
    img = Magick::Image.read(@tmpfile.open).first
    display = img.resize_to_fit(500)  
    S3.put(s3_bucket, filename_display, display.to_blob)  

    t = img.resize_to_fit(150)
    length = t.rows > t.columns ? t.columns : t.rows
    thumbnail =  t.crop(CenterGravity, length, length)
    S3.put(s3_bucket, filename_thumbnail, thumbnail.to_blob)  
  end
  
  def destroy_image_s3
    S3.delete s3_bucket, filename_display
    S3.delete s3_bucket, filename_thumbnail
  end

  def s3_bucket
    "fc.#{album.user.id}"
  end           
  
  def add_activity
    Activity.create(:user => album.user, :activity_type => 'photo', :text => "<a href='/user/#{album.user.nickname}'>#{album.user.formatted_name}</a> added a new photo - <a href='/photo/#{self.id}'><img class='span-1' src='#{self.url_thumbnail}'/></a>")
  end
    
end

class Album
  include DataMapper::Resource
  property :id,         Serial
  property :name,       String, :length => 255
  property :description, Text
  property :created_at, DateTime
  
  belongs_to :user
  has n, :photos
  belongs_to :cover_photo, :class_name => 'Photo', :child_key => [:cover_photo_id]
  after :save, :add_activity
  
  def add_activity
    Activity.create(:user => user, :activity_type => 'album', :text => "<a href='/user/#{user.nickname}'>#{user.formatted_name}</a> created a new album <a href='/album/#{self.id}'>#{self.name}</a>")
  end  
end

class Annotation
  include DataMapper::Resource
  property :id,         Serial
  property :description,Text
  property :x,          Integer
  property :y,          Integer
  property :height,     Integer
  property :width,      Integer
  property :created_at, DateTime
  
  belongs_to :photo
  after :save, :add_activity

  def add_activity
    Activity.create(:user => self.photo.album.user, :activity_type => 'annotation', :text => "<a href='/user/#{self.photo.album.user.nickname}'>#{self.photo.album.user.formatted_name}</a> annotated a photo - <a href='/photo/#{self.photo.id}'><img class='span-1' src='#{self.photo.url_thumbnail}'/></a> with '#{self.description}'")
  end
  
end

class Group                   
  include DataMapper::Resource          
  
  property :id, Serial
  property :name, String
  property :description, String

  has n, :pages
  has n, :members, :class_name => 'User', :through => Resource
  belongs_to :user
  belongs_to :wall
  
  after :create, :create_wall
  
  def create_wall
    self.wall = Wall.create
    self.save
  end

  after :create, :add_activity

  def add_activity
    Activity.create(:user => self.user, :activity_type => 'event', :text => "<a href='/user/#{self.user.nickname}'>#{self.user.formatted_name}</a> created a new group - <a href='/group/#{self.id}'>#{self.name}</a>.")
  end  
end


class Event                   
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String
  property :description, String
  property :venue, String
  property :date, DateTime
  property :time, Time
  
  belongs_to :user
  has n, :pages
  has n, :confirms
  has n, :confirmed_users, :through => :confirms, :class_name => 'User', :child_key => [:event_id], :mutable => true
  has n, :pendings
  has n, :pending_users, :through => :pendings, :class_name => 'User', :child_key => [:event_id], :mutable => true
  has n, :declines
  has n, :declined_users, :through => :declines, :class_name => 'User', :child_key => [:event_id], :mutable => true

  belongs_to :wall
  after :create, :create_wall
  
  def create_wall
    self.wall = Wall.create
    self.save
  end

  after :create, :add_activity

  def add_activity
    Activity.create(:user => self.user, :activity_type => 'event', :text => "<a href='/user/#{self.user.nickname}'>#{self.user.formatted_name}</a> created a new event - <a href='/event/#{self.id}'>#{self.name}</a>.")
  end
      
end

class Pending
  include DataMapper::Resource
  property :id, Serial
  belongs_to :pending_user, :class_name => 'User', :child_key => [:user_id]
  belongs_to :pending_event, :class_name => 'Event', :child_key => [:event_id]

end

class Decline
  include DataMapper::Resource
  property :id, Serial
  belongs_to :declined_user, :class_name => 'User', :child_key => [:user_id]
  belongs_to :declined_event, :class_name => 'Event', :child_key => [:event_id]  
end

class Confirm
  include DataMapper::Resource
  property :id, Serial
  belongs_to :confirmed_user, :class_name => 'User', :child_key => [:user_id]
  belongs_to :confirmed_event, :class_name => 'Event', :child_key => [:event_id]  
end

class Wall           
  include DataMapper::Resource  
  property :id, Serial
  has n, :posts
  
end


class Page
  include DataMapper::Resource
  include Commentable  
  property :id, Serial
  property :title, String
  property :body, Text
  property :created_at, DateTime
  has n, :comments
  has n, :likes
  belongs_to :user
  belongs_to :event
  belongs_to :group
  
  
  after :create, :add_activity

  def add_activity
    if self.event
      Activity.create(:user => self.user, :activity_type => 'event page', :text => "<a href='/user/#{self.user.nickname}'>#{self.user.formatted_name}</a> created a page - <a href='/event/page/#{self.id}'>#{self.title}</a> for the event <a href='/event/#{self.event.id}'>#{self.event.name}</a>.") 
    elsif self.group
      Activity.create(:user => self.user, :activity_type => 'group page', :text => "<a href='/user/#{self.user.nickname}'>#{self.user.formatted_name}</a> created a page - <a href='/group/page/#{self.id}'>#{self.title}</a> for the group <a href='/group/#{self.group.id}'>#{self.group.name}</a>.")       
    else
      Activity.create(:user => self.user, :activity_type => 'page', :text => "<a href='/user/#{self.user.nickname}'>#{self.user.formatted_name}</a> created a page - <a href='/page/#{self.id}'>#{self.title}</a>.")
    end
  end
  

  
end


class Post                    
  include DataMapper::Resource
  include Commentable  
  property :id, Serial
  property :text, Text
  property :created_at, DateTime
  belongs_to :user
  belongs_to :wall
  has n, :comments
  has n, :likes

end         



class Comment 
  include DataMapper::Resource
  
  property :id, Serial
  property :text, Text
  property :created_at, DateTime
  belongs_to :user
  belongs_to :page
  belongs_to :post
  belongs_to :photo
  belongs_to :activity
  belongs_to :status
  
end

class Like
  include DataMapper::Resource
   property :id, Serial
   belongs_to :user
   belongs_to :page
   belongs_to :post
   belongs_to :photo
   belongs_to :activity
   belongs_to :status
         
end

class Request
  include DataMapper::Resource
   property :id, Serial
   property :text, Text
   property :created_at, DateTime
   
   belongs_to :from, :class_name => User, :child_key => [:from_id]
   belongs_to :user
end
    

