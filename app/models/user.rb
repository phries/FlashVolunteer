class User < ActiveRecord::Base
  include ActiveModel::Validations
  validates :email, :presence => { :message => "Must have an e-mail" }
  has_and_belongs_to_many :roles
  has_and_belongs_to_many :skills
  has_and_belongs_to_many :admin_of, :class_name => "Org", :join_table => "orgs_admins", :uniq => true
  has_attached_file :avatar, :storage => :s3, :s3_credentials => {
      :access_key_id => ENV['AWS_ACCESS_KEY'],
      :secret_access_key => ENV['AWS_SECRET_KEY'],
      :bucket => ENV['AWS_BUCKET']
    }, :path => ":attachment/:id/:style.:extension",
    :styles => { :thumb => ["32x32#", :png], :profile => ["128x128#", :png]},
    :default_url => "/assets/default_user_:style.png"
  has_and_belongs_to_many :followers, :class_name => "User", :join_table => "users_followers", :association_foreign_key => "follower_id", :uniq => true
  has_many :participations
  has_many :events_participated, :through => :participations, :source => :event
  belongs_to :neighborhood

  attr_accessor :account_type
  attr_accessor :terms_of_service
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable, :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :terms_of_service, :name, :email, :password, :password_confirmation, :remember_me, :avatar, :birthday, :neighborhood_id, :skill_ids, :account_type

  def role?(role)
    return !!self.roles.find_by_name(role.to_s.camelize)
  end
  
  def should_show_wizard?
    !neighborhood_id || !skills.length
  end

  def password_match?
    self.errors[:password] << 'password not match' if password != password_confirmation
    self.errors[:password] << 'you must provide a password' if password.blank?
    password == password_confirmation and !password.blank?  
  end

  def create_associated_org(org_email, org_name)
    org = Org.new(:email => org_email, :password => Devise.friendly_token[0,20], :name =>org_name)
    org.admins << self
    org.save!
  end

  def self.find_for_oauth(access_token)
    data = access_token.extra.raw_info
    if !(user = User.where(:email => data.email).first)
      user = User.create!(:email => data.email, :password => Devise.friendly_token[0,20], :name => data.name) 
    end
    user
  end

  def send_on_create_confirmation_instructions
    Devise::Mailer.delay.confirmation_instructions(self)
  end
  def send_reset_password_instructions
    Devise::Mailer.delay.reset_password_instructions(self)
  end
  def send_unlock_instructions
    Devise::Mailer.delay.unlock_instructions(self)
  end
end
