%w(dm-core dm-timestamps dm-validations).each {|lib| gem lib, '=0.9.11'}
%w(dm-core dm-timestamps dm-validations RMagick right_aws config).each  { |lib| require lib}
include Magick
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:root@localhost/faceclone')
S3 = RightAws::S3Interface.new(S3_CONFIG['AWS_ACCESS_KEY'], S3_CONFIG['AWS_SECRET_KEY'], {:multi_thread => true, :protocol => 'http', :port => 80} )

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
  has n, :events, :through => Resource
  has n, :pendings
  has n, :pending_events, :through => :pendings, :class_name => 'Event', :child_key => [:id], :parent_key => [:user_id]
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
    f = []
    f += statuses
    friends.each do |friend|
      f += friend.activities
    end
    return f.sort {|x,y| y.created_at <=> x.created_at}
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

end

class Relationship
  include DataMapper::Resource

  property :user_id, Integer, :key => true
  property :follower_id, Integer, :key => true
  belongs_to :user, :child_key => [:user_id]
  belongs_to :follower, :class_name => 'User', :child_key => [:follower_id]
  after :save, :add_activity
  
  def add_activity
    Activity.create(:user => user, :activity_type => 'relationship', :text => "You and <a href='/#{follower.nickname}'>#{follower.formatted_name}</a> are now friends.")
    Activity.create(:user => follower, :activity_type => 'relationship', :text => "You and <a href='/#{user.nickname}'>#{user.formatted_name}</a> are now friends.")    
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

  property :id, Serial
  property :text, String, :length => 160
  property :created_at,  DateTime  
  belongs_to :recipient, :class_name => "User", :child_key => [:recipient_id]
  belongs_to :user  
  has n, :mentions
  has n, :mentioned_users, :through => :mentions, :class_name => 'User', :child_key => [:user_id]
  
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
    Activity.create(:user => user, :activity_type => 'status', :text => "<a href='/#{user.nickname}'>#{user.formatted_name}</a> " + self.text )
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
  
  property :id, Serial
  property :activity_type, String
  property :text, Text
  property :created_at, DateTime
  has n, :likes
  belongs_to :user
end

class Photo
  include DataMapper::Resource
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
    S3.put(s3_bucket, filename_display, @tmpfile)

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
    Activity.create(:user => album.user, :activity_type => 'photo', :text => "<a href='/#{album.user.nickname}'>#{album.user.formatted_name}</a> added a new photo - <a href='/photo/#{self.id}'><img class='span-1' src='#{self.url_thumbnail}'/></a>")
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
    Activity.create(:user => user, :activity_type => 'album', :text => "<a href='/#{user.nickname}'>#{user.formatted_name}</a> created a new album <a href='/album/#{self.id}'>#{self.name}</a>")
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
    Activity.create(:user => self.photo.album.user, :activity_type => 'annotation', :text => "<a href='/#{self.photo.album.user.nickname}'>#{self.photo.album.user.formatted_name}</a> annotated a photo - <a href='/photo/#{self.photo/id}'><img class='span-1' src='#{self.photo.url_thumbnail}'/></a> with '#{self.description}'")
  end
  
end

class Group                   
  include DataMapper::Resource          
  
  property :id, Serial
  property :name, String
  property :description, String
  has n, :pages
  has n, :members, :class_name => 'User', :through => Resource
  belongs_to :wall
end


class Event                   
  include DataMapper::Resource
  
  property :id, Serial
  property :name, String
  property :description, String
  property :venue, String
  property :date, DateTime
  
  has n, :pages
  
  has n, :users, :through => Resource
  has n, :pendings
  has n, :pending_users, :through => :pendings, :class_name => 'User', :child_key => [:id], :parent_key => [:event_id]  

  belongs_to :wall

end

class Pending
  include DataMapper::Resource
  property :id, Serial

  belongs_to :pending_user, :class_name => 'User', :child_key => [:user_id]
  belongs_to :pending_event, :class_name => 'Event', :child_key => [:event_id]

end



class Wall           
  include DataMapper::Resource  
  property :id, Serial
  has n, :posts
  
end


class Page
  include DataMapper::Resource
  property :id, Serial
  property :title, String
  property :body, Text
  property :date_created, DateTime
  belongs_to :user
end


class Post                    
  include DataMapper::Resource
  
  property :id, Serial
  property :text, Text
  property :created_at, DateTime
  belongs_to :user
  belongs_to :wall
  has n, :likes

end         



class Comment 
  include DataMapper::Resource
  
  property :id, Serial
  property :text, Text
  belongs_to :user
  has n, :likes
  
  
end

class Like
  include DataMapper::Resource
   property :id, Serial
   belongs_to :user
   
end

class Request
  include DataMapper::Resource
   property :id, Serial
   property :text, Text
   property :created_at, DateTime
   
   belongs_to :from, :class_name => User, :child_key => [:from_id]
   belongs_to :user
end
    

