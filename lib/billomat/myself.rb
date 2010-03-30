class Billomat::Myself < Billomat::SingletonBase

  # non standard path
  def self.element_name
    "users/myself"
  end

  # get the billomat user for the logged in person
  def user
    Billomat::Users.all.each do |user|
      return user if user.id==self.id
    end
    raise StandardError
  end
end