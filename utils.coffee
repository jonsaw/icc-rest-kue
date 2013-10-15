
request = require 'request'
fs = require 'fs'
Store = require './store'

Utils =
  ###
    Update/insert job data into MongoDb.
    @param {number}
    @param {array}
    @param {function}
  ###
  store: (jobId, data, callback) ->
    Store.findOne {id: jobId}, (err, store) ->
      return callback(err) if err

      if store
        store.data = store.data.concat(data)
      else
        store = new Store({
          id: jobId,
          data: data
          })

      store.save (err) ->
        return callback(err) if err
        callback()

  ###
    Query from api.
    @param {string}
    @param {array}
    @param {string}
    @param {function} callback {string|object}, {array}
  ###
  apiQuery: (url, list, column, callback) ->
    # errors -- early returns
    return callback("Valid URL needed.") if not url
    return callback("A list is needed.") if not list

    options = {
      method: "POST",
      uri: url,
      form: {} 
    }
    options.form[column] = list
    
    request options, (err, response, body) ->
      return callback(err) if err
      return callback("Cannot GET/POST location.") unless response.statusCode is 200

      callback(null, JSON.parse(body))

  ###
    Move file
    @param {string}
    @param {string}
    @param {function}
  ###
  moveFile: (startPath, endPath, callback) ->
    input = fs.createReadStream(startPath)
    output = fs.createWriteStream(endPath)
    
    input.pipe(output)
    input.on 'end', ->
      fs.unlinkSync(startPath)
      callback()

module.exports = Utils
