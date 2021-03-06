class auto_attrs:
    attrs={}                            # sub classes override this

    def __init__(self,arghash):
        # first set args named in attrs; this allows unnamed attrs to have default values as defined in attrs
        for attr,v in self.attrs.items():
            if arghash.has_key(attr):
                self[attr]=arghash[attr]
            else: 
                self[attr]=self.attrs[attr]

        # next set any extra attrs from arghash
        for attr,v in arghash.items():
            if not attr in self.__dict__: self.add_attr(attr,v)

    def __getitem__(self,attr):
        return self.__dict__[attr]

    def __setitem__(self,attr,val):
        self.__dict__[attr]=val
        return val
    
    def attrs_dict(self):
        return self.__dict__
    
    # add a new attribute to an object:
    def add_attr(self,*args):
        attr=args[0]                    # let this fail if not present
        try:
            val=args[1]
        except IndexError as e:
            val=None                    # ok to fail
        self.__dict__[attr]=val
        
