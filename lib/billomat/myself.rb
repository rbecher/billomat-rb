class Billomat::Myself < Billomat::ReadOnlySingletonBase

  # non standard path
  def self.element_name
    'users/myself'
  end
end