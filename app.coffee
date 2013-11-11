
kue = require "kue"
jobs = kue.createQueue()
express = require "express"
request = require "request"
Store = require './store'
routes = require './routes/index'
csv = require 'csv'
fs = require 'fs'
Utils = require './utils'
config = require './config'

# Start a query batch request
kue.app.post "/query/batch/:type", express.bodyParser(), (req, res) ->
  {url, list, column, title} = req.body

  # check if url is present
  return res.send 500, { message: "URL required in body." } unless url

  # check if list is present
  return res.send 500, { message: "List is required in body." } unless list

  # set default title
  title = if title then title else 'generic-batch-query'
  
  job = jobs.create(req.params.type, {
    title: title,
    list: list,
    column: column,
    url: url
    })

  job.on "complete", -> console.log "query batch completed"
  job.on "failed", -> console.log "query batch failed"
  job.on "progress", (progress) -> 
    process.stdout.write "\r job #" + job.id + " " + progress + "% complete"

  job.save (err) ->
    return res.send { id: job.id }

jobs.process "generic-batch-query", (job, done) ->
  next = (i, job, callback) ->
    {list, url, column, chunk} = job.data
    [len, column, chunk] = [list.length, column or 'list', chunk or 10]

    job.progress(i, len)

    if i >= len
      callback()
    else
      chunkedList = list.slice(i, i + chunk)
      Utils.apiQuery url, chunkedList, column, (err, data) ->
        return callback(err) if err
        Utils.store job.id, data, (err) ->
          return callback(err) if err
          next(i + chunk, job, callback)

  next(0, job, done) # run

jobs.process "apt-generateAmazonReplenish", (job, done) ->
  next = (i, job, callback) ->
    {list, url, column, chunk} = job.data
    [len, column, chunk] = [list.length, column or 'list', chunk or 10]
    wipFile = "./csv/wip/apt-generateAmazonReplenish.#{job.created_at}.#{job.id}.csv"
    endFile = "./csv/end/apt-generateAmazonReplenish.#{job.created_at}.#{job.id}.csv"

    job.progress(i, len)

    if i >= len
      # move file to end location
      return Utils.moveFile(wipFile, endFile, callback)

    else
      chunkedList = list.slice(i, i + chunk)
      Utils.apiQuery url, chunkedList, column, (err, data) ->
        return callback(err) if err

        rows = []

        if i is 0
          rows.push ['id', 'asin', 'title', 'count', "fnSku", "asku", "otSku", 
            "otAtp", "otQoh", "otAvgCost", "price","fbaFees", "margin", "store", 
            "condition", "afnWhQty", "afnFulQty", "afnUnselQty", "adsp7", 
            "adsp14", "adsp28", "adsp45", "afnInShipQty", "afnInWorkQty", "doi7", 
            "doi14", "doi28", "doi45", "mTargetDoi", "lShipMethod", "lead", 
            "inbound", "replenishQty", "availableRepQty"]
        for d in data
          if d.archive
            for a in d.archive
              row = [d.id, d.asin, d.title, d.count, 
                a.fnSku, a.asku, a.otSku, a.otAtp, a.otQoh, a.otAvgCost, 
                a.price, a.fbaFees, a.margin, a.store, a.condition, a.afnWhQty, 
                a.afnFulQty, a.afnUnselQty, a.adsp7, a.adsp14, a.adsp28, 
                a.adsp45, a.afnInShipQty, a.afnInWorkQty, a.doi7, a.doi14, 
                a.doi28, a.doi45, a.mTargetDoi, a.lShipMethod, a.lead, 
                a.inbound, a.replenishQty, a.availableRepQty]
              rows.push row
          else
            rows.push [d.id, d.asin, d.title, d.count]
        csv()
          .from.array(rows)
          .to.path(wipFile, {flags: 'a', eof: '\n'})
          .on 'close', ->
            next(i + chunk, job, callback)
          
  next(0, job, done) # run

# Routes
kue.app.get '/store/:id', routes.store
kue.app.get '/status', routes.status
kue.app.get '/csv', routes.csvList
kue.app.get '/csv/download', routes.csvDownload

kue.app.set "title", "ICC Kue"
kue.app.listen(process.env.PORT or config.app.port)