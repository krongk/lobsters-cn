require 'spec_helper'

describe AdminController do

  describe "GET 'index'" do
    it "returns http success" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'biz_email'" do
    it "returns http success" do
      get 'biz_email'
      response.should be_success
    end
  end

end
