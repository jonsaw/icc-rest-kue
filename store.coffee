
mongoose = require 'mongoose'
mongoose.connect "mongodb://localhost/icc-rest-kue_#{process.env.NODE_ENV}"

storeSchema = new mongoose.Schema {
  id: {type: Number, required: true}
  data: []
}

storeSchema.index {id: 1}

Store = mongoose.model('Store', storeSchema)
module.exports = Store