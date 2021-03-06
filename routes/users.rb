class App < Sinatra::Base
  register Sinatra::Namespace

  # Begin users namespace
  namespace '/users' do
  
    # Create new user
    post '/?' do
      content_type 'application/json'
    
      begin
        body_params = JSON.parse(request.body.read)
        required_fields = {"required" => ["email", "first_name", "last_name", "role"]}
        schema = User::SCHEMA.merge(required_fields)
        JSON::Validator.validate!(schema, body_params)
      rescue Exception => e
        give_error(400, ERROR_INVALID_BODY, "The body is not valid.").to_json
      end
      user = case body_params["role"].downcase
               when "blind"
                 Blind.new
               when "helper"
                 Helper.new
               else
                 give_error(400, ERROR_UNDEFINED_ROLE, "Undefined role.").to_json
      end
      if !body_params['password'].nil?
        password = decrypted_password(body_params['password'])
        user.update_attributes body_params.merge({ "password" => password })
      elsif !body_params['user_id'].nil?
        user.update_attributes body_params.merge({ "user_id" => body_params['user_id'] })
      else
        give_error(400, ERROR_INVALID_BODY, "Missing parameter 'user_id' for registering a Facebook user or parameter 'password' for registering a regular user.").to_json
      end
      begin
        user.save!
      rescue Exception => e
        puts e.message
        give_error(400, ERROR_USER_EMAIL_ALREADY_REGISTERED, "The e-mail is already registered.").to_json if e.message.match /email/i
      end

      return user_from_id(user.id2)
    end
    
    # Logout, thereby deleting the token
    put '/logout' do
      content_type 'application/json'
    
      begin
        body_params = JSON.parse(request.body.read)
        token_repr = body_params["token"]
      rescue Exception => e
        give_error(400, ERROR_INVALID_BODY, "The body is not valid.").to_json
      end
            
      token = token_from_representation(token_repr)
      if !token.valid?
        give_error(400, ERROR_USER_TOKEN_EXPIRED, "Token has expired.").to_json
      end
      
      token.delete
      
      return { "success" => true }.to_json
    end
    
    # Login, thereby creating an ew token
    post '/login' do
      content_type 'application/json'
    
      begin
        body_params = JSON.parse(request.body.read)
      rescue Exception => e
        give_error(400, ERROR_INVALID_BODY, "The body is not valid.").to_json
      end
      
      secure_password = body_params["password"]
      user_id = body_params["user_id"]
      
      # We need either a password or a user ID to login
      if secure_password.nil? && user_id.nil?
        give_error(400, ERROR_INVALID_BODY, "Missing password or user ID.").to_json
      end
      
      # We need either an e-mail to login
      if body_params['email'].nil?
        give_error(400, ERROR_INVALID_BODY, "Missing e-mail.").to_json
      end

      if !secure_password.nil?
        # Login using e-mail and password
        password = decrypted_password(secure_password)
        user = User.authenticate_using_email(body_params['email'], password)
        
        # Check if we managed to log in
        if user.nil?
          give_error(400, ERROR_USER_INCORRECT_CREDENTIALS, "No user found matching the credentials.").to_json
        end
      elsif !user_id.nil?
        # Login using user ID
        user = User.authenticate_using_user_id(body_params['email'], body_params['user_id'])    
        
        # Check if we managed to log in
        if user.nil?
          give_error(400, ERROR_USER_FACEBOOK_USER_NOT_FOUND, "The Facebook user was not found.").to_json
        end
      end
      
      # We did log in, create token
      token = Token.new
      token.valid_time = 365.days
      user.tokens.push(token)
      token.save!

      return { "token" => JSON.parse(token.to_json), "user" => JSON.parse(token.user.to_json) }.to_json
    end
    
    # Login with a token
    put '/login/token' do
      content_type 'application/json'
    
      begin
        body_params = JSON.parse(request.body.read)
        token_repr = body_params["token"]
      rescue Exception => e
        give_error(400, ERROR_INVALID_BODY, "The body is not valid.").to_json
      end
      
      token = token_from_representation(token_repr)
      if !token.valid?
        give_error(400, ERROR_USER_TOKEN_EXPIRED, "Token has expired.").to_json
      end

      return { "user" => JSON.parse(token.user.to_json) }.to_json
    end
    
    # Get user by id
    get '/:user_id' do
      content_type 'application/json'
    
      return user_from_id(params[:user_id].to_i).to_json
    end

    # Update a user
    put '/:user_id' do
      user = user_from_id(params[:user_id].to_i)
      begin
        body_params = JSON.parse(request.body.read)
        JSON::Validator.validate!(User::SCHEMA, body_params)
        user.update_attributes!(body_params)
      rescue Exception => e
        puts e.message
        give_error(400, ERROR_INVALID_BODY, "The body is not valid.").to_json
      end
      return user
    end
  
  end # End namespace /users
  
  # Get user from ID
  def user_from_id(user_id)
    user = User.first(:id2 => user_id)
    if user.nil?
      give_error(400, ERROR_USER_NOT_FOUND, "No user found.").to_json
    end
    
    return user
  end
  
  # Find token by representation of the token
  def token_from_representation(repr)
    token = Token.first(:token => repr)
    if token.nil?
      give_error(400, ERROR_USER_TOKEN_NOT_FOUND, "Token not found.").to_json
    end
    
    return token
  end
  
  # Decrypt the password
  def decrypted_password(secure_password)
    begin
      return AESCrypt.decrypt(secure_password, settings.config["security_salt"])
    rescue Exception => e
      give_error(400, ERROR_INVALID_PASSWORD, "The password is invalid.").to_json
    end
  end

end