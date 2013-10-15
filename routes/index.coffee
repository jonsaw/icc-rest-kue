
Store = require '../store'
reds = require 'reds'
redis = require 'redis'
fs = require 'fs'

exports.store = (req, res) ->
  id = req.params.id
  Store.findOne {id: id}, (err, store) ->
    return res.send {error: err.message} if err
    res.send JSON.stringify store

exports.status = (req, res) ->
  reds.createClient = redis.createClient
  search = -> return reds.createSearch('q:search')
  search().query(req.query.q).end (err, ids) ->
    res.send ids

exports.csvList = (req, res) ->
  locations = [
    {status: 'wip', path: './csv/wip'},
    {status: 'end', path: './csv/end'}
  ]

  list = []
  read = (i, done) ->
    if i >= locations.length
      done()
    else
      path = locations[i].path
      fs.readdir path, (err, files) ->
        for file in files.reverse()
          [type, datetime, jobId] = file.split(".")
          fileObj = {
            id: jobId,
            type: type,
            datetime: datetime, 
            status: locations[i].status,
            filename: file,
            filepath: "#{path}/#{file}"
          }

          if req.query.type
            # filter based on type
            list.push fileObj if req.query.type is type
          else
            list.push fileObj
        read(i + 1, done)

  read(0, -> res.send(JSON.stringify(list)))

exports.csvDownload = (req, res) ->
  if not req.query.filepath
    return res.send 500, {error: 'Missing "filepath" in URL query.'} 
    
  res.download req.query.filepath