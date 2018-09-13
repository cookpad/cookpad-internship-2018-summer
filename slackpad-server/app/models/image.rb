require "mini_mime"

class Image < ApplicationRecord
  def decode
    Base64.decode64(data)
  end

  def content_type
    MiniMime.lookup_by_filename(filename).content_type
  end
end
